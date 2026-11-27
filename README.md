# Mihna · مِهنة

**Mihna by [Arandas Tech](https://arandas.tech)**: a workshop logbook for vocational trainees and their supervisors,
Arabic first, English too, that keeps working when the workshop has no signal.

A trainee logs the skills they practised. The supervisor (the usta) signs each one off or sends it back with a note.
The workshop ends up with a record of what a trainee actually did, and what a supervisor approved.

The pilot is **light-vehicle auto repair in Amman**, for 5 to 10 workshops and one training or employer partner.

## What is built

**Slice 1: roles, the checklist, sign-off**

- **Roles per workshop:** trainee, supervisor and admin. Whoever starts a workshop is its admin and adds people by
  the email of their account. The database checks every role on every write.
- **The auto repair checklist:** 32 skills in 8 areas, safety first, in Arabic and English
  ([`lib/models/trade.dart`](lib/models/trade.dart)). It ships inside the app, so it is there before the first sync.
- **Offline queue:** every change is saved on the phone first and sent oldest first when there is signal
  ([`lib/services/change_queue.dart`](lib/services/change_queue.dart)). The server functions are idempotent, so a
  change sent twice changes nothing twice. A refused change is set aside with its reason, never silently dropped.
- **Sign-off:** supervisors see everything waiting, oldest first, and each trainee's progress.

**Slice 2: jobs, attendance and hours**

- **Supervised jobs:** a supervisor gives a trainee a job card (what, which car, which checklist skills it
  practises). The trainee marks it done with the time it took; the job's skills are then logged as practised, so
  they wait for sign-off with the job as their note. The supervisor checks the job and confirms the time that counts,
  or calls off one not started.
- **Attendance:** the trainee checks in and out on their phone, signal or not. One open shift at a time; a shift is
  at most 16 hours. The supervisor confirms each shift, and can fix the times (a forgotten check-out) as they do.
- **Practical hours, two kinds kept apart:** *workshop hours* (confirmed shifts) and *hands-on hours* (checked
  jobs), each with what still waits for a supervisor. Trainees see theirs; supervisors see every trainee's.
- Every id is made on the phone, so all seven new actions go through the same offline queue and are safe to send
  twice ([`supabase/migrations/20261128000000_jobs_and_hours.sql`](supabase/migrations/20261128000000_jobs_and_hours.sql)).

Next, in order: photo and voice evidence, safety induction and PPE sign-off, and a shareable bilingual
verified-skills page. Not planned for the pilot: payroll, a job marketplace, a full LMS, broad compliance reporting,
or automated safety decisions.

## Run it

Flutter 3.50.0. It runs on your own Supabase project: apply `supabase/migrations` to it ([docs/SETUP.md](docs/SETUP.md)),
then:

```bash
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

## Checks

```bash
dart format lib tool test
flutter analyze
flutter test                                # the offline queue, jobs, shifts and hours, and every screen at phone width in both languages
tool/check_layers.sh
node tool/check_arabic.mjs
PGHOST=... PGUSER=... tool/check_sql.sh     # who can see and change what; needs a Postgres 15+
SHOTS=1 flutter test test/screens_test.dart # also saves each screen to .shots/ to look at
```

## Docs

Built from [Zirr Starter](https://github.com/abu-arandas/zirr-starter), so its docs apply:
[ARCHITECTURE.md](ARCHITECTURE.md), [docs/SETUP.md](docs/SETUP.md), [docs/REBRAND.md](docs/REBRAND.md),
[docs/DEPLOY.md](docs/DEPLOY.md), [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md).
