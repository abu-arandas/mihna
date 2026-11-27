-- Jobs, shifts and hours: who can give, finish, check and confirm what, and that every function is safe to send
-- twice. Runs after rls_test.sql, as the API's own role. Each block raises on failure.
--
-- People: 7 admin of workshop C, 8 supervisor in C, 9 trainee in C, 10 trainee in C, 11 admin of workshop D.

insert into auth.users (id, email) values
  ('77777777-7777-7777-7777-777777777777', 'admin@c.test'),
  ('88888888-8888-8888-8888-888888888888', 'usta@c.test'),
  ('99999999-9999-9999-9999-999999999999', 'trainee@c.test'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'other.trainee@c.test'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'admin@d.test');

do $$
declare
  open_tables text := (
    select string_agg(tablename, ', ') from pg_tables where schemaname = 'public' and not rowsecurity
  );
begin
  assert open_tables is null, 'tables without row-level security: ' || open_tables;
end $$;

create temporary table ids (name text primary key, id uuid);
grant all on ids to authenticated;
insert into ids values
  ('job1', 'c0000000-0000-4000-8000-000000000001'),
  ('job2', 'c0000000-0000-4000-8000-000000000002'),
  ('job3', 'c0000000-0000-4000-8000-000000000003'),
  ('shift1', 'd0000000-0000-4000-8000-000000000001'),
  ('shift2', 'd0000000-0000-4000-8000-000000000002'),
  ('shift3', 'd0000000-0000-4000-8000-000000000003');

set role authenticated;

set request.jwt.sub = '77777777-7777-7777-7777-777777777777';
insert into ids select 'c', public.start_workshop('Garage C', 'Abu Samer');
select public.add_member((select id from ids where name = 'c'), 'usta@c.test', 'supervisor', 'Usta Nabil');
select public.add_member((select id from ids where name = 'c'), 'trainee@c.test', 'trainee', 'Laith');
select public.add_member((select id from ids where name = 'c'), 'other.trainee@c.test', 'trainee', 'Hamza');

set request.jwt.sub = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
insert into ids select 'd', public.start_workshop('Garage D', 'Rami');

-- The supervisor gives Laith two jobs, the first one twice (a queued change sent again).
set request.jwt.sub = '88888888-8888-8888-8888-888888888888';
select public.assign_job((select id from ids where name = 'job1'), (select id from ids where name = 'c'),
  '99999999-9999-9999-9999-999999999999', 'Front pads', '2014 Corolla', array['brakes.pads', 'brakes.inspect'], now() - interval '3 hours');
select public.assign_job((select id from ids where name = 'job1'), (select id from ids where name = 'c'),
  '99999999-9999-9999-9999-999999999999', 'Front pads', '2014 Corolla', array['brakes.pads', 'brakes.inspect'], now() - interval '3 hours');
select public.assign_job((select id from ids where name = 'job2'), (select id from ids where name = 'c'),
  '99999999-9999-9999-9999-999999999999', 'Oil change', '', array['service.oil'], now());

do $$
begin
  assert (select count(*) from public.jobs) = 2, 'a repeated assignment makes one job';
  assert (select assigned_by from public.jobs where id = (select id from ids where name = 'job1')) = '88888888-8888-8888-8888-888888888888', 'who gave the job is recorded';
  begin
    perform public.assign_job((select id from ids where name = 'job3'), (select id from ids where name = 'c'),
      '88888888-8888-8888-8888-888888888888', 'For me', '', '{}', now());
    raise exception 'gave a job to a supervisor';
  exception when raise_exception then
    if sqlerrm not like 'Jobs go to a trainee%' then raise; end if;
  end;
  begin
    perform public.assign_job((select id from ids where name = 'job3'), (select id from ids where name = 'c'),
      '99999999-9999-9999-9999-999999999999', 'Bad code', '', array['Not A Code'], now());
    raise exception 'took a skill code the checklist cannot have';
  exception when check_violation then null;
  end;
  begin
    insert into public.jobs (id, workshop_id, trainee_id, title, assigned_at)
      values (gen_random_uuid(), (select id from ids where name = 'c'), '99999999-9999-9999-9999-999999999999', 'Direct', now());
    raise exception 'wrote a job without the function';
  exception when insufficient_privilege then null;
  end;
end $$;

-- Laith sees his jobs, cannot give one, and finishes the first twice.
set request.jwt.sub = '99999999-9999-9999-9999-999999999999';
select public.finish_job((select id from ids where name = 'job1'), 90, 'Pads and a rotor check', now() - interval '1 hour');
select public.finish_job((select id from ids where name = 'job1'), 90, 'Pads and a rotor check', now() - interval '1 hour');

do $$
begin
  assert (select count(*) from public.jobs) = 2, 'the trainee sees his two jobs';
  assert (select status from public.jobs where id = (select id from ids where name = 'job1')) = 'done', 'finished';
  begin
    perform public.assign_job((select id from ids where name = 'job3'), (select id from ids where name = 'c'),
      '99999999-9999-9999-9999-999999999999', 'Self', '', '{}', now());
    raise exception 'a trainee gave himself a job';
  exception when raise_exception then
    if sqlerrm not like 'Only a supervisor%' then raise; end if;
  end;
  begin
    perform public.check_job((select id from ids where name = 'job1'), 90, '', now());
    raise exception 'a trainee checked his own job';
  exception when raise_exception then
    if sqlerrm not like 'Only a supervisor%' then raise; end if;
  end;
end $$;

-- Hamza sees none of it and cannot finish Laith's job.
set request.jwt.sub = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
do $$
begin
  assert (select count(*) from public.jobs) = 0, 'a trainee sees another trainee''s jobs';
  begin
    perform public.finish_job((select id from ids where name = 'job2'), 30, '', now());
    raise exception 'finished someone else''s job';
  exception when raise_exception then
    if sqlerrm not like 'Only the trainee on the job%' then raise; end if;
  end;
end $$;

-- The other workshop's admin can do nothing with workshop C's jobs.
set request.jwt.sub = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
do $$
begin
  assert (select count(*) from public.jobs) = 0, 'another workshop sees the jobs';
  begin
    perform public.check_job((select id from ids where name = 'job1'), 90, '', now());
    raise exception 'checked a job in another workshop';
  exception when raise_exception then
    if sqlerrm not like 'Only a supervisor%' then raise; end if;
  end;
end $$;

-- The supervisor checks the first with a correction (twice), cannot check one not finished, and calls the second off.
set request.jwt.sub = '88888888-8888-8888-8888-888888888888';
select public.check_job((select id from ids where name = 'job1'), 75, 'Rotor check was mine', now());
select public.check_job((select id from ids where name = 'job1'), 75, 'Rotor check was mine', now());

do $$
begin
  assert (select checked_minutes from public.jobs where id = (select id from ids where name = 'job1')) = 75, 'the correction counts';
  assert (select minutes from public.jobs where id = (select id from ids where name = 'job1')) = 90, 'the trainee''s word is kept';
  begin
    perform public.check_job((select id from ids where name = 'job2'), 30, '', now());
    raise exception 'checked a job not finished';
  exception when raise_exception then
    if sqlerrm not like 'The trainee has not finished%' then raise; end if;
  end;
  begin
    perform public.cancel_job((select id from ids where name = 'job1'));
    raise exception 'called off a checked job';
  exception when raise_exception then
    if sqlerrm not like '%already finished%' then raise; end if;
  end;
end $$;

select public.cancel_job((select id from ids where name = 'job2'));
select public.cancel_job((select id from ids where name = 'job2'));

-- A late copy of the trainee's finish leaves the check alone; a called-off job cannot be finished.
set request.jwt.sub = '99999999-9999-9999-9999-999999999999';
select public.finish_job((select id from ids where name = 'job1'), 120, 'late copy', now());

do $$
begin
  assert (select status from public.jobs where id = (select id from ids where name = 'job1')) = 'checked', 'a late finish undid a check';
  assert (select minutes from public.jobs where id = (select id from ids where name = 'job1')) = 90, 'a late finish changed the minutes';
  begin
    perform public.finish_job((select id from ids where name = 'job2'), 30, '', now());
    raise exception 'finished a called-off job';
  exception when raise_exception then
    if sqlerrm not like '%called off%' then raise; end if;
  end;
end $$;

-- Shifts: Laith checks in twice (the same change), cannot open a second shift, checks out twice.
select public.check_in((select id from ids where name = 'shift1'), (select id from ids where name = 'c'), now() - interval '9 hours');
select public.check_in((select id from ids where name = 'shift1'), (select id from ids where name = 'c'), now() - interval '9 hours');

do $$
begin
  assert (select count(*) from public.shifts) = 1, 'a repeated check-in makes one shift';
  begin
    perform public.check_in((select id from ids where name = 'shift2'), (select id from ids where name = 'c'), now());
    raise exception 'opened two shifts at once';
  exception when raise_exception then
    if sqlerrm not like 'You are already checked in' then raise; end if;
  end;
  begin
    perform public.check_out((select id from ids where name = 'shift1'), now() - interval '10 hours');
    raise exception 'checked out before checking in';
  exception when raise_exception then
    if sqlerrm not like 'Check-out comes after%' then raise; end if;
  end;
  begin
    perform public.confirm_shift((select id from ids where name = 'shift1'), now() - interval '9 hours', now(), now());
    raise exception 'a trainee confirmed his own shift';
  exception when raise_exception then
    if sqlerrm not like 'Only a supervisor%' then raise; end if;
  end;
end $$;

select public.check_out((select id from ids where name = 'shift1'), now() - interval '1 hour');
select public.check_out((select id from ids where name = 'shift1'), now() - interval '1 hour');
-- A second shift that he forgets to check out of.
select public.check_in((select id from ids where name = 'shift2'), (select id from ids where name = 'c'), now() - interval '30 minutes');

do $$
begin
  assert (select count(*) from public.shifts) = 2, 'two shifts';
  assert (select check_out from public.shifts where id = (select id from ids where name = 'shift1')) is not null, 'checked out';
end $$;

-- Hamza cannot see or close Laith's shifts, and needs his own role to check in.
set request.jwt.sub = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
do $$
begin
  assert (select count(*) from public.shifts) = 0, 'a trainee sees another trainee''s shifts';
  begin
    perform public.check_out((select id from ids where name = 'shift2'), now());
    raise exception 'checked someone else out';
  exception when raise_exception then
    if sqlerrm not like 'Only the trainee on the shift%' then raise; end if;
  end;
  begin
    perform public.check_in((select id from ids where name = 'shift3'), (select id from ids where name = 'd'), now());
    raise exception 'checked in to a workshop he is not in';
  exception when raise_exception then
    if sqlerrm not like 'Only a trainee checks in' then raise; end if;
  end;
end $$;

-- The supervisor confirms the first shift as it is (twice), and closes the forgotten one with a check-out.
set request.jwt.sub = '88888888-8888-8888-8888-888888888888';
do $$
declare
  s public.shifts := (select s from public.shifts s where id = (select id from ids where name = 'shift1'));
begin
  perform public.confirm_shift(s.id, s.check_in, s.check_out, now());
  perform public.confirm_shift(s.id, s.check_in, s.check_out, now());
  assert (select confirmed_by from public.shifts where id = s.id) = '88888888-8888-8888-8888-888888888888', 'confirmed';
  begin
    perform public.confirm_shift(s.id, s.check_in, s.check_out + interval '1 hour', now());
    raise exception 'changed a confirmed shift';
  exception when raise_exception then
    if sqlerrm not like '%already confirmed%' then raise; end if;
  end;
  begin
    perform public.confirm_shift(s.id, s.check_in, s.check_in + interval '17 hours', now());
    raise exception 'took a 17-hour shift';
  exception when raise_exception then
    if sqlerrm not like '%already confirmed%' then raise; end if;
  end;
end $$;

select public.confirm_shift((select id from ids where name = 'shift2'), now() - interval '30 minutes', now() - interval '5 minutes', now());

do $$
begin
  assert (select count(*) from public.shifts where confirmed_at is not null) = 2, 'both shifts confirmed';
  begin
    perform public.confirm_shift((select id from ids where name = 'shift2'), now(), now() + interval '17 hours', now());
    raise exception 'changed a confirmed shift';
  exception when raise_exception then
    if sqlerrm not like '%already confirmed%' then raise; end if;
  end;
end $$;

-- The trainee's late check-out of the forgotten shift leaves the supervisor's time alone, and he can check in again.
set request.jwt.sub = '99999999-9999-9999-9999-999999999999';
select public.check_out((select id from ids where name = 'shift2'), now());
select public.check_in((select id from ids where name = 'shift3'), (select id from ids where name = 'c'), now());

do $$
begin
  assert (select check_out from public.shifts where id = (select id from ids where name = 'shift2')) < now() - interval '1 minute',
    'a late check-out changed a confirmed shift';
  assert (select count(*) from public.shifts) = 3, 'checked in again after the forgotten shift was closed';
  -- The hours that count: 8 confirmed workshop hours plus 25 minutes, and 75 hands-on minutes.
  -- (Each statement has its own now(), so allow a second either way.)
  assert (select sum(check_out - check_in) from public.shifts where confirmed_at is not null)
    between interval '8 hours 24 minutes 59 seconds' and interval '8 hours 25 minutes 1 second', 'workshop hours';
  assert (select sum(checked_minutes) from public.jobs where status = 'checked') = 75, 'hands-on minutes';
end $$;

-- Removing a trainee takes his jobs and shifts with him.
set request.jwt.sub = '77777777-7777-7777-7777-777777777777';
select public.remove_member((select id from ids where name = 'c'), '99999999-9999-9999-9999-999999999999');
do $$
begin
  assert (select count(*) from public.jobs) + (select count(*) from public.shifts) = 0, 'a removed trainee''s jobs or shifts stay';
end $$;

reset role;
set role anon;

do $$
begin
  perform count(*) from public.shifts;
  raise exception 'signed-out visitors can read shifts';
exception when insufficient_privilege then null;
end $$;

reset role;
