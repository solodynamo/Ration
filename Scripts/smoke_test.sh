#!/bin/bash
# Lightweight end-to-end check: launch the actual packaged app (not just
# `swift test`) and confirm it comes up as a backgrounded, Dock-less menu
# bar process and doesn't crash within a few seconds. This is a smoke test,
# not full UI interaction — Ration has no accessible window until its menu
# bar icon is clicked, so scripted clicking would need a signed, notarized
# build plus Accessibility permissions that CI runners don't grant.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/Ration.app"
BINARY="$APP_BUNDLE/Contents/MacOS/Ration"

if [ ! -x "$BINARY" ]; then
    echo "error: $BINARY not found — run build_app.sh first" >&2
    exit 1
fi

echo "==> Launching $APP_BUNDLE"
open "$APP_BUNDLE"
sleep 4

PID=$(pgrep -f "$BINARY" || true)
if [ -z "$PID" ]; then
    echo "FAIL: process did not stay running" >&2
    exit 1
fi
echo "==> Process is running (pid $PID)"

# System Events automation needs an Accessibility grant that CI runners may
# not have preauthorized, so treat this check as best-effort: fail on it
# only when it actually ran and disagreed, not when the OS blocked it.
if BACKGROUND_ONLY=$(osascript -e 'tell application "System Events" to get name of every process whose background only is true' 2>/tmp/smoke_osascript.err); then
    if [[ "$BACKGROUND_ONLY" != *"Ration"* ]]; then
        echo "FAIL: Ration did not register as a background-only (accessory) process" >&2
        kill "$PID" 2>/dev/null || true
        exit 1
    fi
    echo "==> Registered as accessory process (no Dock icon)"
else
    echo "warning: skipped accessory-process check (System Events automation unavailable): $(cat /tmp/smoke_osascript.err)"
fi

kill "$PID" 2>/dev/null || true
echo "==> Smoke test passed"
