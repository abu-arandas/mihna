# Setup

The app always runs on a Supabase project: there is no demo mode and no sample data. A build without keys, or with
keys that cannot be right, shows why instead of starting.

## A Supabase project

1. Create a project at supabase.com. Pick the region the client's data must stay in (Frankfurt is closest to
   Jordan) and write it down for the client: data-protection law cares where data lives.
2. Run the migrations in `supabase/migrations`, oldest first: paste each into the SQL editor, or use the Supabase
   CLI (`supabase link` then `supabase db push`).
3. Decide who makes accounts (see "Sign-up and password reset" below). People can create their own from the
   sign-in page, or you can add them in **Authentication → Users** with an email and password.
4. In **Project Settings → API**, copy the project URL and the **publishable** (anon) key. Never put the service-role
   key in the app or in git.
5. Run with both:

```bash
flutter run -d chrome --dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

A build given no keys, or keys that cannot be right (not https, or too short), shows why instead of starting.

## Sign-up and password reset

The sign-in page links to **Create an account** and **Forgot your password?**. Both send emails whose links open the
app, so the Supabase project has to know where the app lives:

1. In **Authentication → URL Configuration**, set **Site URL** to the app's address (for example
   `https://app.example.com`), and add the same address to **Redirect URLs**. For local work, also add
   `http://localhost:*`.
2. To send the links somewhere other than the Site URL (a staging build, say), build with
   `--dart-define=AUTH_REDIRECT_URL=https://staging.example.com`. That address must be in **Redirect URLs** too.
3. In **Authentication → Providers → Email**, choose whether new accounts must **confirm their email**. With it on,
   sign-up tells the person to check their inbox; with it off, they are signed in at once. Set the **minimum password
   length** to 8 or less: the app asks for 8 (`AuthChecks.minPasswordLength`).
4. Supabase's built-in mailer sends only a few emails an hour and is meant for testing. Before launch, set up your
   own SMTP under **Authentication → Emails**, and edit the email templates (confirm signup, reset password) in
   Arabic and English.

A reset link opens the app signed in, on **Choose a new password**. Because Supabase uses PKCE, the link must be
opened in the same browser (or on the same phone) that asked for it.

**A product without self sign-up:** set `Brand.allowSignUp` to `false`, which hides the link and the page, and turn off
**Allow new users to sign up** under **Authentication → Providers → Email**. The Supabase setting is what really stops
it; the flag only tidies the screen.

**Phones:** on Android and iOS, the links only come back into the app once deep links are set up for the app's
address (see supabase_flutter's deep-link guide). Until then, use the web build for sign-up confirmation and resets.

## SQL tests

`tool/check_sql.sh` creates a throwaway database, loads `supabase/tests/supabase_stub.sql` (just enough of
Supabase's auth schema and roles for plain Postgres), applies every migration and runs every
`supabase/tests/*_test.sql`. Each test raises an error on failure.

```bash
PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres tool/check_sql.sh
```

Add a test file for each table's policies: who can read, add, change and delete, and who cannot.
