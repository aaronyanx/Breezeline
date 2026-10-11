#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="build/Breezeline.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
WORK="$(mktemp -d /tmp/breezeline-dmg.XXXXXX)"
ditto "$APP" "$WORK/Breezeline.app"
cp LICENSE "$WORK/LICENSE.txt"
ln -s /Applications "$WORK/Applications"
DMG="build/Breezeline-${VERSION}.dmg"
if [ -e "$DMG" ]; then mv "$DMG" "$WORK/../Breezeline-${VERSION}-$(date +%s).dmg"; fi
hdiutil create -srcfolder "$WORK" -volname Breezeline -format UDZO -fs HFS+ "$DMG"
hdiutil verify "$DMG"
