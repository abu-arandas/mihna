# Dependencies

Every package the app depends on directly, as resolved in `pubspec.lock` on 2026-11-12 with Flutter 3.50.0. Keep
this list current when a dependency is added or upgraded: buyers and reviewers read it.

| Package | Version | Licence | Why |
|---|---|---|---|
| Flutter SDK | 3.50.0 (Dart 3.14.0) | BSD-3-Clause | The framework |
| `material_ui` | 1.11.0 | BSD-3-Clause | The Material widgets and their Arabic and English strings (out of the SDK since Flutter 3.50; brings `cupertino_ui` 1.1.6) |
| `flutter_localizations` | SDK | BSD-3-Clause | Only for the old Material strings GetX's own app needs (see ARCHITECTURE.md) |
| `get` | 4.7.3, pinned | MIT | State, DI, routing and `.tr` in controllers and views. Single maintainer: see ARCHITECTURE.md |
| `postgrest` | 2.9.1 | MIT | The plain-Dart PostgREST client the services use for Neon's Data API |
| `http` | 1.6.0 | BSD-3-Clause | Neon Auth's HTTP API (`NeonAuthService`), and the Data API underneath `postgrest` |
| `shared_preferences` | see `pubspec.lock` | BSD-3-Clause | The phone's storage for the offline queue and the session (`lib/platform`) |
| `sentry` | 10.6.0 | BSD-3-Clause | Error reports, sent only when the build is given a `SENTRY_DSN` (`lib/config/errors.dart`, docs/DEPLOY.md) |

Dev only: `flutter_lints` 6.0.0 (BSD-3-Clause).

Not used, on purpose: `flutter_bootstrap5` (no release since August 2022; `lib/config/breakpoints.dart` replaces
it).

Check for updates with `flutter pub outdated`. Upgrade one package at a time, with CI green after each.

## Assets

| Asset | Licence | Where from |
|---|---|---|
| Rubik (`assets/fonts/Rubik.ttf`, variable, weights 300 to 900) | SIL Open Font License 1.1 | https://fonts.google.com/specimen/Rubik |
| The Zirr button mark (`tool/brand/*.svg` and the icons made from it) | Zirr's own, not for reuse in a client's brand | Drawn for Zirr |

Credit every asset a product adds here, with its licence, and only use assets licensed for commercial use.
