-- Row-level security and the write functions: who can see and change what, in their workshop and in nobody else's.
-- Runs as the API's own role, since a superuser skips RLS. Each block raises on failure.
--
-- People: 1 admin of workshop A, 2 supervisor in A, 3 trainee in A, 4 trainee in A, 5 admin of workshop B, 6 nobody.

insert into neon_auth."user" (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'admin@a.test'),
  ('22222222-2222-2222-2222-222222222222', 'usta@a.test'),
  ('33333333-3333-3333-3333-333333333333', 'trainee@a.test'),
  ('44444444-4444-4444-4444-444444444444', 'other.trainee@a.test'),
  ('55555555-5555-5555-5555-555555555555', 'admin@b.test'),
  ('66666666-6666-6666-6666-666666666666', 'nobody@test');

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

set role authenticated;

-- The admin starts workshop A and adds people by email.
set request.jwt.sub = '11111111-1111-1111-1111-111111111111';
insert into ids select 'a', public.start_workshop('Abu Ali Auto', 'Abu Ali');
select public.add_member((select id from ids where name = 'a'), 'USTA@a.test', 'supervisor', 'Usta Khaled');
select public.add_member((select id from ids where name = 'a'), 'trainee@a.test', 'trainee', 'Omar');
select public.add_member((select id from ids where name = 'a'), 'other.trainee@a.test', 'trainee', 'Yazan');

do $$
begin
  assert (select count(*) from public.members) = 4, 'the admin sees the four people in their workshop';
  assert public.my_role((select id from ids where name = 'a')) = 'admin', 'the starter is the admin';
  begin
    perform public.add_member((select id from ids where name = 'a'), 'missing@test', 'trainee', 'X');
    raise exception 'added an email with no account';
  exception when raise_exception then
    if sqlerrm not like 'No account%' then raise; end if;
  end;
  begin
    insert into public.workshops (name) values ('Direct');
    raise exception 'wrote a workshop without the function';
  exception when insufficient_privilege then null;
  end;
end $$;

-- Workshop B, someone else's.
set request.jwt.sub = '55555555-5555-5555-5555-555555555555';
insert into ids select 'b', public.start_workshop('Other Garage', 'Rami');

do $$
begin
  assert (select count(*) from public.workshops) = 1, 'sees another workshop';
  assert (select count(*) from public.members) = 1, 'sees another workshop''s people';
  begin
    perform public.add_member((select id from ids where name = 'a'), 'admin@b.test', 'admin', 'Intruder');
    raise exception 'joined a workshop they are not admin of';
  exception when raise_exception then
    if sqlerrm not like 'Only an admin%' then raise; end if;
  end;
end $$;

-- The trainee logs practice, twice (a queued change sent again).
set request.jwt.sub = '33333333-3333-3333-3333-333333333333';
select public.practise_skill((select id from ids where name = 'a'), 'brakes.pads', 'Front pads on a Corolla', now() - interval '2 hours');
select public.practise_skill((select id from ids where name = 'a'), 'brakes.pads', 'Front pads on a Corolla', now() - interval '2 hours');
select public.practise_skill((select id from ids where name = 'a'), 'service.oil', '', now());

do $$
begin
  assert (select count(*) from public.skill_records) = 2, 'a repeated change makes one row';
  begin
    perform public.review_skill((select id from ids where name = 'a'), '33333333-3333-3333-3333-333333333333', 'brakes.pads', 'signed_off', '', now());
    raise exception 'a trainee signed off their own skill';
  exception when raise_exception then
    if sqlerrm not like 'Only a supervisor%' then raise; end if;
  end;
  begin
    perform public.practise_skill((select id from ids where name = 'b'), 'brakes.pads', '', now());
    raise exception 'logged practice in a workshop they are not in';
  exception when raise_exception then
    if sqlerrm not like 'Only a trainee%' then raise; end if;
  end;
  begin
    update public.skill_records set status = 'signed_off';
    raise exception 'signed off by writing the table';
  exception when insufficient_privilege then null;
  end;
end $$;

-- The other trainee sees none of it.
set request.jwt.sub = '44444444-4444-4444-4444-444444444444';
do $$
begin
  assert (select count(*) from public.skill_records) = 0, 'a trainee sees another trainee''s record';
end $$;

-- The supervisor signs one off and sends the other back; both twice.
set request.jwt.sub = '22222222-2222-2222-2222-222222222222';
select public.review_skill((select id from ids where name = 'a'), '33333333-3333-3333-3333-333333333333', 'brakes.pads', 'signed_off', 'Clean job', now());
select public.review_skill((select id from ids where name = 'a'), '33333333-3333-3333-3333-333333333333', 'brakes.pads', 'signed_off', 'Clean job', now());
select public.review_skill((select id from ids where name = 'a'), '33333333-3333-3333-3333-333333333333', 'service.oil', 'returned', 'Torque the drain plug', now());

do $$
begin
  assert (select count(*) from public.skill_records) = 2, 'the supervisor sees the workshop''s records';
  assert (select status from public.skill_records where skill_code = 'brakes.pads') = 'signed_off', 'signed off';
  assert (select reviewed_by from public.skill_records where skill_code = 'brakes.pads') = '22222222-2222-2222-2222-222222222222', 'the reviewer is recorded';
  begin
    perform public.review_skill((select id from ids where name = 'a'), '33333333-3333-3333-3333-333333333333', 'brakes.pads', 'returned', '', now());
    raise exception 'took back a sign-off';
  exception when raise_exception then
    if sqlerrm not like '%already signed off%' then raise; end if;
  end;
  begin
    perform public.add_member((select id from ids where name = 'a'), 'nobody@test', 'trainee', 'X');
    raise exception 'a supervisor added people';
  exception when raise_exception then
    if sqlerrm not like 'Only an admin%' then raise; end if;
  end;
end $$;

-- Practising again keeps a sign-off, and reopens a skill sent back.
set request.jwt.sub = '33333333-3333-3333-3333-333333333333';
select public.practise_skill((select id from ids where name = 'a'), 'brakes.pads', 'again', now());
select public.practise_skill((select id from ids where name = 'a'), 'service.oil', 'Torqued to spec', now());

do $$
begin
  assert (select status from public.skill_records where skill_code = 'brakes.pads') = 'signed_off', 'practice undid a sign-off';
  assert (select status from public.skill_records where skill_code = 'service.oil') = 'practised', 'a sent-back skill reopens';
  assert (select review_note from public.skill_records where skill_code = 'service.oil') = '', 'the old review note is cleared';
end $$;

-- Someone with no workshop sees nothing.
set request.jwt.sub = '66666666-6666-6666-6666-666666666666';
do $$
begin
  assert (select count(*) from public.workshops) + (select count(*) from public.members) + (select count(*) from public.skill_records) = 0,
    'an outsider sees workshop data';
end $$;

-- The admin removes a trainee; their records go too.
set request.jwt.sub = '11111111-1111-1111-1111-111111111111';
select public.remove_member((select id from ids where name = 'a'), '33333333-3333-3333-3333-333333333333');
do $$
begin
  assert (select count(*) from public.skill_records) = 0, 'a removed trainee''s records stay';
  assert (select count(*) from public.members) = 3, 'the trainee was not removed';
end $$;

reset role;
set role anonymous;

do $$
begin
  perform count(*) from public.skill_records;
  raise exception 'signed-out visitors can read skill records';
exception when insufficient_privilege then null;
end $$;

reset role;
