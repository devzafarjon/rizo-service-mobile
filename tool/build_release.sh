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
    flutter build appbundle --release --dart-define=API_URL="$api" --dart-define=WEB_URL="$web"
    cp build/app/outputs/bundle/release/app-release.aab "$out/aab/$name.aab"
    flutter build ios --release --no-codesign --dart-define=API_URL="$api" --dart-define=WEB_URL="$web"
    tmp="$(mktemp -d)"; mkdir "$tmp/Payload"; cp -R build/ios/iphoneos/Runner.app "$tmp/Payload/"
    rm -f "$out/ios/$name-imzosiz.ipa"; ( cd "$tmp" && ditto -c -k --sequesterRsrc --keepParent Payload "$out/ios/$name-imzosiz.ipa" ) )
done
# Sanity check: the address compiled into each APK must be exactly the one asked for.
for name in RIZO-Texnik RIZO-Mijoz; do
  dir="$(mktemp -d)"; unzip -q -o "$out/apk/$name.apk" 'lib/arm64-v8a/libapp.so' -d "$dir"
  strings -a "$dir/lib/arm64-v8a/libapp.so" | grep -qxF "$api" && echo "$name: server address OK ($api)" || { echo "$name: WRONG server address in the build" >&2; exit 1; }
done
