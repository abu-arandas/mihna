-- Just enough of Neon (Neon Auth's user table, the Data API's roles and auth.uid()) to run the migrations on a plain
-- Postgres. Like Neon, the API roles get nothing by default: the migrations grant what they need.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anonymous') then create role anonymous; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated; end if;
end $$;
create schema neon_auth;
create table neon_auth."user" (id uuid primary key, name text not null default '', email text not null, "emailVerified" boolean not null default false);
create schema auth;
-- On Neon this reads the token's sub claim; here a test sets request.jwt.sub.
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.sub', true), '')::uuid $$;
grant usage on schema auth to anonymous, authenticated;
