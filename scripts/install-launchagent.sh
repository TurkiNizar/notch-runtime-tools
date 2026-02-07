#!/bin/bash
set -euo pipefail

PLIST_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/launch/com.notch-runtime-tools.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.notch-runtime-tools.plist"

echo "Installing LaunchAgent to start Notch Runtime Tools for Developers at login..."
mkdir -p "$(dirname "$PLIST_DST")"
cp "$PLIST_SRC" "$PLIST_DST"
launchctl unload "$PLIST_DST" >/dev/null 2>&1 || true
launchctl load "$PLIST_DST"
echo "LaunchAgent installed and loaded."
