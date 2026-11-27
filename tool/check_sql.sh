#!/usr/bin/env bash
# Builds a throwaway database from the migrations and runs every test in supabase/tests. Each test raises on failure.
# Needs psql and a Postgres 15+ it may create databases on: set PGHOST, PGPORT and PGUSER as usual.
set -euo pipefail
cd "$(dirname "$0")/.."
db="starter_check_$$"
psql -q -v ON_ERROR_STOP=1 -d postgres -c "create database $db" >/dev/null
trap 'psql -q -d postgres -c "drop database if exists $db" >/dev/null' EXIT
psql -q -v ON_ERROR_STOP=1 -d "$db" -f supabase/tests/supabase_stub.sql >/dev/null
for f in supabase/migrations/*.sql; do psql -q -v ON_ERROR_STOP=1 -d "$db" -f "$f" >/dev/null; done
for t in supabase/tests/*_test.sql; do
  psql -q -t -v ON_ERROR_STOP=1 -d "$db" -f "$t"
  echo "ok: $t"
done
