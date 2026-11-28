-- Mihna's second slice: the jobs a supervisor gives a trainee, the trainee's shifts in the workshop, and the hours
-- both add up to once a supervisor has confirmed them.
--
-- Same rules as the first slice: every table has row-level security and is read through its select policy, and the
-- app writes only through the functions below, which check the caller's role. Each row's id is made on the phone,
-- so a queued change sent twice (it went out, but the answer was lost) finds its row and changes nothing twice.
--
-- Two kinds of hours, kept apart on purpose:
--   * workshop hours: from check-in to check-out, confirmed by a supervisor;
--   * hands-on hours: the time the trainee spent on a job, confirmed by the supervisor who checked the job.

create type public.job_status as enum ('assigned', 'done', 'checked', 'cancelled');

-- A job card: a real car, a real task, given to one trainee, practising some skills of the checklist.
create table public.jobs (
  id uuid primary key,
  workshop_id uuid not null references public.workshops on delete cascade,
  trainee_id uuid not null,
  assigned_by uuid,
  title text not null check (length(trim(title)) between 1 and 120),
  vehicle text not null default '' check (length(vehicle) <= 80),
  -- Codes from the trade's checklist (lib/models/trade.dart), at most 12.
  skill_codes text[] not null default '{}' check (
    cardinality(skill_codes) <= 12 and array_to_string(skill_codes, ',') ~ '^([a-z0-9_.]{2,60}(,|$))*$'
  ),
  status public.job_status not null default 'assigned',
  assigned_at timestamptz not null,
  -- The trainee's word, when they mark it done.
  minutes integer check (minutes between 1 and 720),
  note text not null default '' check (length(note) <= 1000),
  done_at timestamptz,
  -- The supervisor's, when they check it. checked_minutes is what counts.
  checked_by uuid,
  checked_minutes integer check (checked_minutes between 1 and 720),
  check_note text not null default '' check (length(check_note) <= 1000),
  checked_at timestamptz,
  updated_at timestamptz not null default now(),
  foreign key (workshop_id, trainee_id) references public.members (workshop_id, user_id) on delete cascade
);

create index jobs_workshop on public.jobs (workshop_id, trainee_id);

-- A shift: when a trainee checked in and out, as their phone saw it.
create table public.shifts (
  id uuid primary key,
  workshop_id uuid not null references public.workshops on delete cascade,
  trainee_id uuid not null,
  check_in timestamptz not null,
  check_out timestamptz,
  confirmed_by uuid,
  confirmed_at timestamptz,
  updated_at timestamptz not null default now(),
  check (check_out is null or (check_out > check_in and check_out <= check_in + interval '16 hours')),
  check (confirmed_at is null or check_out is not null),
  foreign key (workshop_id, trainee_id) references public.members (workshop_id, user_id) on delete cascade
);

create index shifts_workshop on public.shifts (workshop_id, trainee_id, check_in);
-- One open shift per trainee and workshop: checking in twice without checking out is a mistake, not two shifts.
create unique index shifts_one_open on public.shifts (workshop_id, trainee_id) where check_out is null;

alter table public.jobs enable row level security;
alter table public.shifts enable row level security;

-- As with skills: a trainee sees their own, supervisors and admins the whole workshop's.
create policy "jobs: own, or the workshop's for supervisors" on public.jobs
  for select to authenticated using (
    trainee_id = (select auth.uid()) or public.my_role(workshop_id) in ('supervisor', 'admin')
  );

create policy "shifts: own, or the workshop's for supervisors" on public.shifts
  for select to authenticated using (
    trainee_id = (select auth.uid()) or public.my_role(workshop_id) in ('supervisor', 'admin')
  );

revoke all on public.jobs, public.shifts from anonymous;
revoke insert, update, delete on public.jobs, public.shifts from authenticated;
grant select on public.jobs, public.shifts to authenticated;

-- True when the caller supervises (or runs) the workshop.
create function public.i_supervise(ws uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(public.my_role(ws) in ('supervisor', 'admin'), false)
$$;

-- A supervisor gives a trainee a job. Sent again, it updates the job while the trainee has not finished it.
create function public.assign_job(p_id uuid, p_workshop uuid, p_trainee uuid, p_title text, p_vehicle text, p_skills text[], p_at timestamptz)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
begin
  if not public.i_supervise(p_workshop) then
    raise exception 'Only a supervisor can give out jobs' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.members where workshop_id = p_workshop and user_id = p_trainee and role = 'trainee') then
    raise exception 'Jobs go to a trainee in this workshop' using errcode = 'P0001';
  end if;
  if p_at > now() + interval '1 day' then raise exception 'That time is in the future' using errcode = 'P0001'; end if;
  insert into public.jobs (id, workshop_id, trainee_id, assigned_by, title, vehicle, skill_codes, assigned_at)
    values (p_id, p_workshop, p_trainee, me, trim(p_title), coalesce(trim(p_vehicle), ''), coalesce(p_skills, '{}'), p_at)
  on conflict (id) do update
    set trainee_id = excluded.trainee_id, title = excluded.title, vehicle = excluded.vehicle,
        skill_codes = excluded.skill_codes, updated_at = now()
    where public.jobs.workshop_id = p_workshop and public.jobs.status = 'assigned';
end $$;

-- A supervisor calls off a job the trainee has not finished. Calling it off again changes nothing.
create function public.cancel_job(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_job public.jobs;
begin
  select * into v_job from public.jobs where id = p_id for update;
  if v_job.id is null or not public.i_supervise(v_job.workshop_id) then
    raise exception 'Only a supervisor can call off a job' using errcode = 'P0001';
  end if;
  if v_job.status = 'cancelled' then return; end if;
  if v_job.status <> 'assigned' then
    raise exception 'The trainee already finished this job' using errcode = 'P0001';
  end if;
  update public.jobs set status = 'cancelled', updated_at = now() where id = p_id;
end $$;

-- The trainee marks their job done, with the time it took and a note. Sent again before it is checked, it updates
-- them; once checked, the supervisor's numbers stand and a late copy changes nothing.
create function public.finish_job(p_id uuid, p_minutes integer, p_note text, p_at timestamptz) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  v_job public.jobs;
begin
  select * into v_job from public.jobs where id = p_id for update;
  if v_job.id is null or v_job.trainee_id <> me or public.my_role(v_job.workshop_id) is distinct from 'trainee' then
    raise exception 'Only the trainee on the job can finish it' using errcode = 'P0001';
  end if;
  if v_job.status = 'checked' then return; end if;
  if v_job.status = 'cancelled' then raise exception 'This job was called off' using errcode = 'P0001'; end if;
  if p_at > now() + interval '1 day' then raise exception 'That time is in the future' using errcode = 'P0001'; end if;
  update public.jobs
    set status = 'done', minutes = p_minutes, note = coalesce(trim(p_note), ''), done_at = p_at, updated_at = now()
    where id = p_id;
end $$;

-- A supervisor checks a finished job and confirms the time that counts (the trainee's, or a correction). Checking
-- it again changes nothing; nobody checks their own job.
create function public.check_job(p_id uuid, p_minutes integer, p_note text, p_at timestamptz) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  v_job public.jobs;
begin
  select * into v_job from public.jobs where id = p_id for update;
  if v_job.id is null or not public.i_supervise(v_job.workshop_id) then
    raise exception 'Only a supervisor can check jobs' using errcode = 'P0001';
  end if;
  if v_job.trainee_id = me then raise exception 'You cannot check your own job' using errcode = 'P0001'; end if;
  if v_job.status = 'checked' then return; end if;
  if v_job.status <> 'done' then
    raise exception 'The trainee has not finished this job yet' using errcode = 'P0001';
  end if;
  update public.jobs
    set status = 'checked', checked_by = me, checked_minutes = coalesce(p_minutes, v_job.minutes),
        check_note = coalesce(trim(p_note), ''), checked_at = least(p_at, now()), updated_at = now()
    where id = p_id;
end $$;

-- The trainee checks in. Sent again, it changes nothing; checking in while another shift is open is refused.
create function public.check_in(p_id uuid, p_workshop uuid, p_at timestamptz) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
begin
  if public.my_role(p_workshop) is distinct from 'trainee' then
    raise exception 'Only a trainee checks in' using errcode = 'P0001';
  end if;
  if p_at > now() + interval '1 day' then raise exception 'That time is in the future' using errcode = 'P0001'; end if;
  if exists (select 1 from public.shifts where id = p_id) then return; end if;
  begin
    insert into public.shifts (id, workshop_id, trainee_id, check_in) values (p_id, p_workshop, me, p_at);
  exception when unique_violation then
    raise exception 'You are already checked in' using errcode = 'P0001';
  end;
end $$;

-- The trainee checks out. Sent again, or after a supervisor already closed the shift, it changes nothing.
create function public.check_out(p_id uuid, p_at timestamptz) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  v_shift public.shifts;
begin
  select * into v_shift from public.shifts where id = p_id for update;
  if v_shift.id is null or v_shift.trainee_id <> me then
    raise exception 'Only the trainee on the shift can check out' using errcode = 'P0001';
  end if;
  if v_shift.check_out is not null then return; end if;
  if p_at <= v_shift.check_in then raise exception 'Check-out comes after check-in' using errcode = 'P0001'; end if;
  if p_at > v_shift.check_in + interval '16 hours' then
    raise exception 'A shift is at most 16 hours. Ask your supervisor to fix the time.' using errcode = 'P0001';
  end if;
  update public.shifts set check_out = p_at, updated_at = now() where id = p_id;
end $$;

-- A supervisor confirms a shift, with its times as they were: the trainee's, or a correction (a forgotten
-- check-out). Confirming again with the same times changes nothing; a confirmed shift is final.
create function public.confirm_shift(p_id uuid, p_check_in timestamptz, p_check_out timestamptz, p_at timestamptz) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  v_shift public.shifts;
begin
  select * into v_shift from public.shifts where id = p_id for update;
  if v_shift.id is null or not public.i_supervise(v_shift.workshop_id) then
    raise exception 'Only a supervisor can confirm shifts' using errcode = 'P0001';
  end if;
  if v_shift.trainee_id = me then raise exception 'You cannot confirm your own shift' using errcode = 'P0001'; end if;
  if v_shift.confirmed_at is not null then
    if v_shift.check_in = p_check_in and v_shift.check_out = p_check_out then return; end if;
    raise exception 'This shift is already confirmed' using errcode = 'P0001';
  end if;
  if p_check_out is null or p_check_out <= p_check_in then
    raise exception 'Check-out comes after check-in' using errcode = 'P0001';
  end if;
  if p_check_out > p_check_in + interval '16 hours' then
    raise exception 'A shift is at most 16 hours' using errcode = 'P0001';
  end if;
  if p_check_out > now() + interval '1 day' then raise exception 'That time is in the future' using errcode = 'P0001'; end if;
  update public.shifts
    set check_in = p_check_in, check_out = p_check_out, confirmed_by = me, confirmed_at = least(p_at, now()), updated_at = now()
    where id = p_id;
end $$;

revoke execute on function public.i_supervise, public.assign_job, public.cancel_job, public.finish_job, public.check_job,
  public.check_in, public.check_out, public.confirm_shift from public, anonymous;
grant execute on function public.i_supervise, public.assign_job, public.cancel_job, public.finish_job, public.check_job,
  public.check_in, public.check_out, public.confirm_shift to authenticated;
