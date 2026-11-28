#!/usr/bin/env bash
# Builds the web app on Vercel, which has no Flutter: fetches the Flutter release the app is tested on, then builds
# against the pilot's Neon project. Both addresses are public (docs/SETUP.md); the database decides who sees what.
set -euo pipefail
FLUTTER_VERSION=3.50.0
FLUTTER_DIR="${TMPDIR:-/tmp}/flutter-$FLUTTER_VERSION"
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
flutter config --no-analytics >/dev/null
flutter build web --release --no-wasm-dry-run \
  --dart-define=NEON_AUTH_URL="${NEON_AUTH_URL:-https://ep-wild-mud-bgfsi5x8.neonauth.c-9.eu-central-1.aws.neon.tech/neondb/auth}" \
  --dart-define=NEON_DATA_API_URL="${NEON_DATA_API_URL:-https://ep-wild-mud-bgfsi5x8.apirest.c-9.eu-central-1.aws.neon.tech/neondb/rest/v1}"
