-- Mihna's first slice: workshops, the people in them and their role, and the skills each trainee has practised and
-- had signed off.
--
-- Every table has row-level security and is read through its select policy. Writes do not go to the tables: the app
-- calls the functions at the end, which check the caller's role and keep each change idempotent, so a phone that sends
-- the same queued change twice (it went out, but the answer was lost in a weak signal) changes nothing the second time.

create type public.member_role as enum ('trainee', 'supervisor', 'admin');
create type public.skill_status as enum ('practised', 'signed_off', 'returned');

create table public.workshops (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 120),
  -- The trade whose checklist the workshop uses (lib/models/trade.dart). The pilot has one: auto_repair.
  trade text not null default 'auto_repair' check (trade ~ '^[a-z_]{2,40}$'),
  created_by uuid not null default auth.uid() references auth.users on delete restrict,
  created_at timestamptz not null default now()
);

create table public.members (
  workshop_id uuid not null references public.workshops on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  role public.member_role not null,
  display_name text not null check (length(trim(display_name)) between 1 and 80),
  added_by uuid references auth.users on delete set null,
  created_at timestamptz not null default now(),
  primary key (workshop_id, user_id)
);

create index members_user on public.members (user_id);

-- One row per trainee and skill: practising again after a supervisor sent it back updates the same row.
create table public.skill_records (
  id uuid primary key default gen_random_uuid(),
  workshop_id uuid not null references public.workshops on delete cascade,
  trainee_id uuid not null references auth.users on delete cascade,
  skill_code text not null check (skill_code ~ '^[a-z0-9_.]{2,60}$'),
  status public.skill_status not null default 'practised',
  note text not null default '' check (length(note) <= 1000),
  -- When it happened in the workshop, as the phone saw it, not when the signal came back.
  practised_at timestamptz not null,
  reviewed_by uuid references auth.users on delete set null,
  review_note text not null default '' check (length(review_note) <= 1000),
  reviewed_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (workshop_id, trainee_id, skill_code),
  foreign key (workshop_id, trainee_id) references public.members (workshop_id, user_id) on delete cascade
);

-- The caller's role in a workshop, or null. Security definer so the policies below can ask it without the members
-- policy reading itself.
create function public.my_role(ws uuid) returns public.member_role
language sql stable security definer set search_path = '' as $$
  select role from public.members where workshop_id = ws and user_id = (select auth.uid())
$$;

alter table public.workshops enable row level security;
alter table public.members enable row level security;
alter table public.skill_records enable row level security;

create policy "workshops: members read theirs" on public.workshops
  for select to authenticated using (public.my_role(id) is not null);

create policy "members: members read their workshop's people" on public.members
  for select to authenticated using (public.my_role(workshop_id) is not null);

-- A trainee sees their own record; supervisors and admins see the whole workshop's.
create policy "skill_records: own, or the workshop's for supervisors" on public.skill_records
  for select to authenticated using (
    trainee_id = (select auth.uid()) or public.my_role(workshop_id) in ('supervisor', 'admin')
  );

-- No insert, update or delete policies: with RLS on, direct writes are refused. The functions below do them.
revoke all on public.workshops, public.members, public.skill_records from anon;
revoke insert, update, delete on public.workshops, public.members, public.skill_records from authenticated;

-- Starts a workshop and makes the caller its admin. Returns the workshop's id.
create function public.start_workshop(p_name text, p_display_name text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  ws uuid;
begin
  if me is null then raise exception 'Sign in first' using errcode = 'P0001'; end if;
  insert into public.workshops (name, created_by) values (trim(p_name), me) returning id into ws;
  insert into public.members (workshop_id, user_id, role, display_name, added_by)
    values (ws, me, 'admin', coalesce(nullif(trim(p_display_name), ''), 'Admin'), me);
  return ws;
end $$;

-- An admin adds someone who already has an account, by email, or changes the role of someone already in.
create function public.add_member(p_workshop uuid, p_email text, p_role public.member_role, p_display_name text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  them uuid;
begin
  if public.my_role(p_workshop) is distinct from 'admin' then
    raise exception 'Only an admin can add people' using errcode = 'P0001';
  end if;
  select id into them from auth.users where lower(email) = lower(trim(p_email));
  if them is null then
    raise exception 'No account has that email. Ask them to create one first.' using errcode = 'P0001';
  end if;
  if them = me and p_role <> 'admin' then
    raise exception 'You cannot change your own role' using errcode = 'P0001';
  end if;
  insert into public.members (workshop_id, user_id, role, display_name, added_by)
    values (p_workshop, them, p_role, trim(p_display_name), me)
  on conflict (workshop_id, user_id) do update set role = excluded.role, display_name = excluded.display_name;
end $$;

-- An admin takes someone out of the workshop. Their skill records go with them (the pilot keeps no orphans).
create function public.remove_member(p_workshop uuid, p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if public.my_role(p_workshop) is distinct from 'admin' then
    raise exception 'Only an admin can remove people' using errcode = 'P0001';
  end if;
  if p_user = (select auth.uid()) then raise exception 'You cannot remove yourself' using errcode = 'P0001'; end if;
  delete from public.members where workshop_id = p_workshop and user_id = p_user;
end $$;

-- A trainee records that they practised a skill. Sent again, it only updates the note and time. A skill already
-- signed off stays signed off.
create function public.practise_skill(p_workshop uuid, p_skill text, p_note text, p_at timestamptz) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
begin
  if public.my_role(p_workshop) is distinct from 'trainee' then
    raise exception 'Only a trainee can log practice' using errcode = 'P0001';
  end if;
  if p_at > now() + interval '1 day' then raise exception 'That time is in the future' using errcode = 'P0001'; end if;
  insert into public.skill_records (workshop_id, trainee_id, skill_code, note, practised_at)
    values (p_workshop, me, p_skill, coalesce(trim(p_note), ''), p_at)
  on conflict (workshop_id, trainee_id, skill_code) do update
    set status = 'practised', note = excluded.note, practised_at = excluded.practised_at,
        reviewed_by = null, review_note = '', reviewed_at = null, updated_at = now()
    where public.skill_records.status <> 'signed_off';
end $$;

-- A supervisor or admin signs a practised skill off, or sends it back with a note. Sending the same decision again
-- changes nothing; nobody signs off their own skill.
create function public.review_skill(p_workshop uuid, p_trainee uuid, p_skill text, p_decision public.skill_status, p_note text, p_at timestamptz)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  v_status public.skill_status;
begin
  if public.my_role(p_workshop) not in ('supervisor', 'admin') or public.my_role(p_workshop) is null then
    raise exception 'Only a supervisor can sign off skills' using errcode = 'P0001';
  end if;
  if p_decision = 'practised' then raise exception 'A review signs off or sends back' using errcode = 'P0001'; end if;
  if p_trainee = me then raise exception 'You cannot sign off your own skill' using errcode = 'P0001'; end if;
  select status into v_status from public.skill_records
    where workshop_id = p_workshop and trainee_id = p_trainee and skill_code = p_skill for update;
  if v_status is null then raise exception 'The trainee has not logged this skill yet' using errcode = 'P0001'; end if;
  if v_status = p_decision then return; end if;
  if v_status = 'signed_off' then raise exception 'This skill is already signed off' using errcode = 'P0001'; end if;
  update public.skill_records
    set status = p_decision, reviewed_by = me, review_note = coalesce(trim(p_note), ''), reviewed_at = least(p_at, now()), updated_at = now()
    where workshop_id = p_workshop and trainee_id = p_trainee and skill_code = p_skill;
end $$;

revoke execute on function public.my_role, public.start_workshop, public.add_member, public.remove_member,
  public.practise_skill, public.review_skill from public, anon;
grant execute on function public.my_role, public.start_workshop, public.add_member, public.remove_member,
  public.practise_skill, public.review_skill to authenticated;
