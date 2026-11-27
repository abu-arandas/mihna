# Rebranding

## In the Dart code: one file

Change [`lib/config/brand.dart`](../lib/config/brand.dart): the name in English and Arabic, the short name (`slug`, which names
the product in the developer log and in error reports), the seed colour every
palette is made from, the accent colour, the font and the languages (the first one is the language the app opens in). For a font,
put the file under `assets/fonts`, add a `fonts:` entry to `pubspec.yaml` with a family name, and set
`fontFamily` to that name.

## Outside the Dart code

These ship with the build and are read before the app starts, so they cannot come from `brand.dart`.

| What | File | Change |
|---|---|---|
| Browser tab and search previews | `web/index.html` | `<title>`, `<meta name="description">`, `<meta name="apple-mobile-web-app-title">` |
| Installed web app | `web/manifest.json` | `name`, `short_name` (12 characters or fewer), `description`, `theme_color` (same as the seed colour), `background_color` |
| Browser bar colour | `web/index.html` | `<meta name="theme-color">` (same as the seed colour) |
| Web icons | `web/favicon.svg`, `web/favicon.png`, `web/icons/*` | Redraw `tool/brand/mark.svg` and `tool/brand/app_icon.svg`, then run `node tool/brand/make_icons.mjs` |
| Android app name | `android/app/src/main/AndroidManifest.xml` | `android:label` |
| Android app id | `android/app/build.gradle.kts` | `namespace` and `applicationId`, then move `MainActivity.kt` to the matching folder under `android/app/src/main/kotlin` and change its `package` line |
| iPhone app name | `ios/Runner/Info.plist` | `CFBundleDisplayName` |
| iPhone bundle id | `ios/Runner.xcodeproj/project.pbxproj` | every `PRODUCT_BUNDLE_IDENTIFIER` |
| App icons | `android/app/src/main/res/mipmap-*`, `ios/Runner/Assets.xcassets/AppIcon.appiconset` | Made by the same `node tool/brand/make_icons.mjs` (needs Node and Playwright's Chromium) |

Then check that nothing old is left:

```bash
grep -rni "zirr" lib web android/app/src ios/Runner
```

It should print only what you meant to keep.
