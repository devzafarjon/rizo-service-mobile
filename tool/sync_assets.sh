#!/usr/bin/env bash
# Copies the web app's translations and logo into the shared Flutter package, so both apps use the same wording.
# Run it after changing client/src/i18n/locales/*.json in rizo-service-full.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
web="${RIZO_WEB_DIR:-$here/../rizo-service-full/client}"
for l in uz ru en; do cp "$web/src/i18n/locales/$l.json" "$here/packages/rizo_core/assets/locales/$l.json"; done
cp "$web/public/rizo-logo.png" "$here/packages/rizo_core/assets/rizo-logo.png"
echo "Synced locales and logo from $web"
