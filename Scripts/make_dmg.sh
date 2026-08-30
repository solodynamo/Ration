#!/bin/bash
# Packages dist/Ration.app (produced by build_app.sh) into a distributable
# .dmg with a drag-to-Applications shortcut. Uses only hdiutil, which ships
# with macOS — no extra tooling or paid services required.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/Ration.app"
VERSION="${RATION_VERSION:-0.1.0}"
DMG_PATH="$DIST_DIR/Ration-$VERSION.dmg"
STAGING_DIR="$DIST_DIR/dmg-staging"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "error: $APP_BUNDLE not found — run build_app.sh first" >&2
    exit 1
fi

echo "==> Staging DMG contents"
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating $DMG_PATH"
hdiutil create -volname "Ration $VERSION" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"
echo "==> Built $DMG_PATH"
