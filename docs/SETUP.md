# Setup

The app always runs on a Neon project: Postgres for the records, **Neon Auth** for accounts, and the **Data API** (which
speaks PostgREST) between the app and the database. There is no demo mode and no sample data. A build without the
project's addresses, or with addresses that cannot be right, shows why instead of starting.

Why Neon: the whole security model is Postgres (row-level security, and every write through a function that checks the
caller's role and is safe to send twice), so it moves unchanged. Neon's free plan has room for this project next to
others, and an idle database sleeps and wakes on the next request instead of being paused for good.

## A Neon project

1. Create a project at [console.neon.tech](https://console.neon.tech). Pick the region the client's data must stay in
   (**AWS Europe (Frankfurt)** is closest to Jordan) and write it down for the client: data-protection law cares where
   data lives. Use Postgres 17 or 18 (the Data API does not run on 19 yet).
2. Turn on **Auth** (the project's **Auth** page). This creates the `neon_auth` schema, where accounts live.
3. Turn on the **Data API** (the project's **Data API** page), with **Neon Auth** as its auth provider. Leave
   "Grant public schema access" off: the migrations grant exactly what the app needs.
4. Run the migrations in `db/migrations`, oldest first, in the **SQL Editor** (or with `psql "<connection string>" -f
   <file>`). They need steps 2 and 3 first: they read `neon_auth."user"` and use the `authenticated` and `anonymous`
   roles the Data API creates.
5. Under **Auth → Configuration**, copy the **Auth URL** (ends in `/auth`). Under **Data API**, copy the **API URL**
   (ends in `/rest/v1`). Neither is a secret; the database decides what each person may do.
6. Under **Auth → Configuration → Domains**, add `https://mihna.arandas.tech` (`Brand.appOrigin`) as a trusted domain,
   and the address the web build is served from if it is a different one. Phone builds send `Brand.appOrigin` as
   their `Origin`; Neon Auth refuses sign-in from an origin it does not trust.
7. Run with both addresses:

```bash
flutter run --dart-define=NEON_AUTH_URL=https://<endpoint>.neonauth.<region>.aws.neon.tech/neondb/auth \
  --dart-define=NEON_DATA_API_URL=https://<endpoint>.apirest.<region>.aws.neon.tech/neondb/rest/v1
```

For local web work, `flutter run -d chrome --web-port 5173` works while **Allow localhost** is on in the Auth settings
(the default). Turn it off before launch.

## Accounts and password reset

- **Sign-up** is open by default: people create their own account from the sign-in page, then an admin adds them to a
  workshop by that email. For a product whose accounts are made by an admin, set `Brand.allowSignUp` to `false` and
  turn off sign-up in the Auth settings, which is what really stops it.
- **Email verification** is off by default and the pilot keeps it off: workshops add people they know by email. If you
  turn on "Verify at sign-up", sign-up tells the person to check their email before signing in.
- **Password reset** is by code, not link, so it works on a phone with no deep links: "Forgot your password?" emails a
  6-digit code (Neon Auth's Email OTP, which must be on in the Auth settings), and the next page takes the code and the
  new password, then signs in.
- Neon's shared mailer (`auth@mail.myneon.app`) is rate-limited and meant for testing. Before launch, set your own SMTP
  under **Auth → Configuration → Email**, set the application name to Mihna, and word the emails in Arabic and English.
- Neon Auth's minimum password length must be 8 or less: the app asks for 8 (`AuthChecks.minPasswordLength`).

**How the app holds a session.** Neon Auth's session is a cookie. A phone build keeps that cookie, with who is signed
in, on the phone (`NeonAuthService`), so the app opens signed in with no signal, and fetches a short-lived token (about
15 minutes) for the Data API when it has signal. A web build lets the browser keep the cookie; because the app and
Neon Auth are on different sites, that needs Neon Auth's session cookie set to `SameSite=None`, or the web build
served from the same site. The phones are the pilot's target; check the web build against the real project before
relying on it.

## SQL tests

`tool/check_sql.sh` creates a throwaway database, loads `db/tests/neon_stub.sql` (just enough of Neon Auth's user
table, the Data API's roles and `auth.uid()` for plain Postgres), applies every migration and runs every
`db/tests/*_test.sql`. Each test raises an error on failure.

```bash
PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres tool/check_sql.sh
```

Add a test file for each table's policies: who can read, add, change and delete, and who cannot.
