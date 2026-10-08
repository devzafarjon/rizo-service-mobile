#!/usr/bin/env bash
# Builds release APKs, Play Market bundles (AAB) and unsigned IPAs of both apps for the production server and copies them to ~/Desktop/RIZO/{apk,aab,ios}.
# Android builds are signed with the upload keystore from android/key.properties (kept out of git); without it they fall back to the debug key.
# Usage:  ./tool/build_release.sh [API_URL] [WEB_URL]
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
api="${1:-https://rizo-service-api.onrender.com}"
web="${2:-https://rizo-service-full.netlify.app}"
out="${RIZO_OUT_DIR:-$HOME/Desktop/RIZO}"
mkdir -p "$out/apk" "$out/aab" "$out/ios"
for pair in "rizo_staff:RIZO-Texnik" "rizo_customer:RIZO-Mijoz"; do
  app="${pair%%:*}"; name="${pair##*:}"
  ( cd "$here/apps/$app"
    flutter pub get >/dev/null
    # Each --dart-define must be its own argument (never put both in one variable).
    flutter build apk --release --dart-define=API_URL="$api" --dart-define=WEB_URL="$web"
    cp build/app/outputs/flutter-apk/app-release.apk "$out/apk/$name.apk"
    # Without the Android "cmdline-tools" Flutter cannot strip debug symbols and exits non-zero, yet Gradle still writes the bundle.
    # So accept the exit code only when the bundle exists and is newer than every source file (install cmdline-tools in
    # Android Studio's SDK Manager to silence this).
    flutter build appbundle --release --dart-define=API_URL="$api" --dart-define=WEB_URL="$web" || echo "WARNING: flutter reported a problem building the bundle; checking the .aab is current" >&2
    aab="build/app/outputs/bundle/release/app-release.aab"
    if [ ! -f "$aab" ] || [ -n "$(find lib android/app pubspec.yaml "$here/packages/rizo_core/lib" "$here/packages/rizo_core/assets" -type f -newer "$aab" 2>/dev/null | head -1)" ]; then
      echo "$name: the app bundle was NOT built (missing or older than the sources)" >&2; exit 1
    fi
    cp "$aab" "$out/aab/$name.aab"
    flutter build ios --release --no-codesign --dart-define=API_URL="$api" --dart-define=WEB_URL="$web"
    tmp="$(mktemp -d)"; mkdir "$tmp/Payload"; cp -R build/ios/iphoneos/Runner.app "$tmp/Payload/"
    rm -f "$out/ios/$name-imzosiz.ipa"; ( cd "$tmp" && zip -qry "$out/ios/$name-imzosiz.ipa" Payload ) )
done
# Sanity check: the address compiled into each APK must be exactly the one asked for.
for name in RIZO-Texnik RIZO-Mijoz; do
  dir="$(mktemp -d)"; unzip -q -o "$out/apk/$name.apk" 'lib/arm64-v8a/libapp.so' -d "$dir"
  # Count instead of "grep -q": -q quits early, strings gets SIGPIPE and pipefail turns a correct build into a false alarm.
  hits="$(strings -a "$dir/lib/arm64-v8a/libapp.so" | grep -cxF "$api" || true)"
  if [ "$hits" -ge 1 ]; then echo "$name: server address OK ($api)"; else echo "$name: WRONG server address in the build" >&2; exit 1; fi
done
