# Architecture

Mihna keeps the Arandas Tech house structure from Zirr Starter, with three changes, each for the offline queue:

- **`lib/platform/`** holds the one piece of platform storage the services need (`PrefsStore`, the phone's own
  storage behind the plain-Dart `LocalStore`). Services stay free of Flutter (rule 1).
- **Writes go through database functions, not tables.** `supabase/migrations` gives every table RLS and a select
  policy, and refuses direct inserts, updates and deletes. The app calls `start_workshop`, `add_member`,
  `remove_member`, `practise_skill` and `review_skill`, which check the caller's role and are safe to call twice,
  so a change the queue resends after a lost answer does no harm.
- **There are Dart tests** (`test/`): the queue's ordering, retry, replacement and refusal rules, and every main
  screen at phone width in Arabic and English, light and dark. Their stand-in services live only in `test/`.

The rest of this file is the starter's, unchanged.

The Zirr house structure. Every product starts from this repository, so a reviewer who has read one
product's code can find their way around all of them. A product that breaks a rule here says so in its own
ARCHITECTURE.md, with the reason.

## Folders

```
lib/
  main.dart        startup only: read the keys, open Supabase, run the app (no keys: the startup problem), all
                   inside runReportingErrors (config/errors.dart)
  app.dart         GetMaterialApp: theme, translations, routes, the startup-problem screen
  config/
    brand.dart     the rebrand file: name (EN/AR), seed colour, font, languages
    env.dart       SUPABASE_URL and SUPABASE_ANON_KEY from --dart-define; both are required. SENTRY_DSN is optional
    errors.dart    every error nothing caught: to the developer log, and to Sentry when the build has a DSN
    theme.dart     light and dark themes from the brand colour, in the house style
    breakpoints.dart  Bootstrap's 576/768/992/1200/1400 breakpoints, GridContainer, GridRow, GridCol
    routes.dart    route names and pages
  models/          plain Dart records: immutable, JSON in and out, nothing else
  services/        every read and write: an interface and its Supabase implementation
  controllers/     GetX controllers: a screen's state, calling services
  bindings/        GetX dependency injection: the one place that picks the services
  views/           pages, one folder per feature
  widgets/         UI shared by more than one feature (motion.dart and fun.dart: the motion and the light lines)
  l10n/            Arabic for every English text; English text is its own key
supabase/
  migrations/      every schema change, in order, with its row-level security
  tests/           SQL tests of the policies (tool/check_sql.sh)
tool/              check_layers.sh (rules 1 and 3), check_arabic.mjs (rule 6), check_sql.sh (rule 4)
docs/              SETUP, REBRAND, DEPLOY, DEPENDENCIES
```

Envato's reviewers look for models, controllers, services, widgets and screens. They are all here; `views` is
the screens.

## Rules

1. **`lib/models` and `lib/services` import neither GetX nor Flutter.** They are plain Dart (`package:supabase`,
   not `supabase_flutter`), so state management can change without touching how records are read and written.
   `tool/check_layers.sh` fails the build on a stray import.
2. **Controllers depend on service interfaces, never on Supabase.** `AppBinding` decides the implementation, and
   `main.dart` hands it the Supabase ones.
3. **Real data only.** Every build runs on a Supabase project. There is no demo mode, no sample data and no seed
   script in the app or in `supabase/`; a build without keys shows why it cannot start. `tool/check_layers.sh`
   fails on a stand-in class (`Memory*`, `Demo*`, `Fake*`, `Sample*`, `Mock*`) in `lib` or a seed file.
4. **The database is the security boundary.** Every table gets row-level security in the migration that creates
   it, one policy per action, and SQL tests in `supabase/tests`. `rls_test.sql` fails if any public table has
   RLS off. The app only ever holds the publishable key; anything that needs more runs in an Edge Function.
5. **No secrets in git.** Keys come from `--dart-define` at build time.
6. **Every text is translated.** Write English and look it up with `.tr`; add the Arabic to `lib/l10n/ar.dart`.
   `node tool/check_arabic.mjs` fails when one is missing. Use start/end, never left/right, so Arabic mirrors.
7. **Brand values come from `config/brand.dart`,** never from string literals in views (docs/REBRAND.md).
8. **Long lists are built lazily** (`ListView.builder`, `SliverList.builder`).
9. **Errors become messages.** Controllers catch failures and set an `error` the screen shows; nothing a person
   does should crash a page. What nothing caught goes to `config/errors.dart`: the developer log always, the build's
   Sentry project when it was given a `SENTRY_DSN`, and in a release build a quiet notice in place of a part of a
   screen that failed to build.
10. **CI is the bar:** `dart format`, `flutter analyze` with zero issues under the house rules in
   `analysis_options.yaml`, the layer and Arabic checks, the SQL tests, and a web build. There are no app tests:
   the SQL tests are what prove one person cannot reach another's rows.

## Tenancy

The sample table keeps each person to their own rows (`owner_id = auth.uid()`). A product sold to businesses
adds a `tenant_id` to every table and checks membership in each policy; the policies and their tests then become
the most important code in the product. A licensed product handed to an agency usually gets its own Supabase
project instead, which is the simplest isolation.

## Why GetX, and the way out

GetX gives routing, dependency injection and reactive state in one small package. It is maintained by one person,
its 5.0 has been a release candidate since 2023, and in April 2026 its repository disappeared for five days. So:

- `get` is pinned to an exact version in `pubspec.yaml` and upgraded on purpose, with the tests.
- It is used only in `controllers`, `bindings`, `views`, `widgets`, `l10n` and `app.dart`. Models and services
  never see it (rule 1).
- Leaving it means rewriting controllers as Riverpod notifiers or Blocs, `AppBinding` as providers, `.tr` as
  `intl` or `flutter_localizations` lookups, and `GetMaterialApp` as `MaterialApp.router`. Models, services, SQL
  and tests of services stay as they are.
- If the package disappeared again, the community fork `getx_community` is the stop-gap.
- Flutter 3.50 moved the Material widgets out of the SDK into `package:material_ui`, but GetX 4.7.3 still builds
  on the old `package:flutter/material.dart`, whose `ThemeData` is a different type. So `app.dart` gives
  `GetMaterialApp` no theme: the theme reaches the pages through `builder:`, and the old Material strings are
  listed beside the new ones. Everything else imports `material_ui`. When GetX moves to `material_ui`, pass the
  themes to `GetMaterialApp` again and drop the two old delegates.

## The house style

`config/theme.dart` puts the Zirr house style on top of the brand colours, so a rebrand keeps it: headings
semibold and a touch tight, corners that flow into the sides (`AppTheme.shape`, a superellipse), fields that are a
soft well until used and then turn white with a ring of the primary colour, pill buttons that rise a little on hover,
a flat app bar that only casts a shadow when something scrolls under it, and calm motion. The one ornament is
`widgets/stitch_line.dart`, a short line of stitches in the accent colour under a page's main heading. Zirr Retail
describes the same style at length in its docs/DESIGN.md.

### Motion and voice

The starter is a work tool, so its motion is calm and quick, and every number is a token in `config/theme.dart`
(`fast`, `slow`, `sew`, `stagger`, `rise`, `curve`, `enter`, `pop`), used through `widgets/motion.dart`:

- Sign-in settles in once: the name, the stitch sewing itself in (`SewIn`), then the form a step at a time.
- Buttons give a little under a press (`PressScale`). A new note settles into the list; a ticked one fades back as it
  is struck through.
- One small celebration: when every note is ticked off, a check pops in with a light line.
- Empty lists and the not-found page (any unknown address; a lost button rolls in, `widgets/fun.dart`) carry one
  short, kind line, in a few versions that change per run (`funLine`), written separately in Arabic and English.
  Never on an error, never at the person's expense.
- With reduce motion on, everything simply shows.

## Responsive layout

`config/breakpoints.dart` replaces flutter_bootstrap5, which has had no release since August 2022. It keeps
Bootstrap's model in about 120 lines: `context.screen` and `context.responsive(...)` for choices,
`GridContainer` for a centred page, and `GridRow` / `GridCol(md: 6, lg: 4)` for a 12-column grid that wraps and
follows the reading direction.
