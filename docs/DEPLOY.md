# Deploy

Every build takes the Neon project's two addresses with `--dart-define` (docs/SETUP.md). A build without them shows
why it cannot start.

## Web

```bash
flutter build web --release --wasm --dart-define=NEON_AUTH_URL=... --dart-define=NEON_DATA_API_URL=...
```

Serve `build/web` from any static host (Vercel, Netlify, Cloudflare Pages, nginx). Send every unknown path to
`index.html` so links to app pages open. Add the web address to Neon Auth's trusted domains.

The pilot's web app is on Vercel (project `mihna`, linked to this repository), served at https://mihna.arandas.tech
through a CNAME on Porkbun. `vercel.json` sends every path to `index.html`, and `tool/vercel_build.sh` fetches the
Flutter release the app is tested on and builds against the pilot's Neon project, so each push to `main` redeploys.

## Android

```bash
flutter build appbundle --release --dart-define=NEON_AUTH_URL=... --dart-define=NEON_DATA_API_URL=...
```

Signing for Google Play: create an upload key, reference it from `android/key.properties` (kept out of git), and
follow Flutter's "Build and release an Android app" guide. Use `flutter build apk --release` for an APK to install by hand.

## iPhone

```bash
flutter build ipa --release --dart-define=NEON_AUTH_URL=... --dart-define=NEON_DATA_API_URL=...
```

Needs a Mac with Xcode and an Apple Developer account; set the team and bundle id in Xcode first.

## Error reports (Sentry)

An error nothing in the app caught (a screen that failed to draw, a reply the app did not expect) is written to the
developer log, the browser console on the web. To hear about the ones people meet, make a free account at
[Sentry](https://sentry.io), a Flutter project in it, and give its DSN (project Settings, Client Keys) to the build:

```bash
flutter build web --release --wasm --dart-define=NEON_AUTH_URL=... --dart-define=NEON_DATA_API_URL=... \
  --dart-define=SENTRY_DSN=https://...ingest.sentry.io/... --dart-define=SENTRY_RELEASE=$(git rev-parse --short HEAD)
```

The Android and iPhone builds take the same two defines. `SENTRY_RELEASE` is optional; with it, each report names the
commit as `<Brand.slug>@<commit>`. Without `SENTRY_DSN` the app sends nothing anywhere.

Each report carries the error, where in the code it happened, the page and the browser or device; never who is signed
in or what they typed. Sentry also sees the sender's IP address: turn on "Prevent Storing of IP Addresses" in the
project's Security & Privacy settings so it keeps none. The DSN only lets an app send reports, so it is safe in the
build. A host that sends a Content-Security-Policy must allow `connect-src https://*.sentry.io`.

## Database

Apply new files in `db/migrations` before deploying an app that needs them, and never edit a migration that
has already run on a client's project: add a new one.
