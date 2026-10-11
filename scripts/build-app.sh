#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
VERSION="0.1.0"
APP="build/Breezeline.app"
WORK="$(mktemp -d /tmp/breezeline-build.XXXXXX)"
# SDK 27 in Command Line Tools lacks the macro plugin needed by SwiftUI.
if [ -z "${SDKROOT:-}" ]; then
  SDKROOT="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk | sort -V | tail -1)"
  export SDKROOT
fi
for arch in arm64 x86_64; do
  swift build -c "$CONFIG" --triple "$arch-apple-macosx14.0"
  BIN="$(swift build -c "$CONFIG" --triple "$arch-apple-macosx14.0" --show-bin-path)"
  cp "$BIN/Breezeline" "$WORK/Breezeline-$arch"
done

STAGED="$WORK/Breezeline.app"
mkdir -p "$STAGED/Contents/MacOS" "$STAGED/Contents/Resources"
lipo -create "$WORK/Breezeline-arm64" "$WORK/Breezeline-x86_64" \
  -output "$STAGED/Contents/MacOS/Breezeline"
swift scripts/make-icon.swift "$WORK/icon.png" "$WORK/Breezeline-menu.png"
mkdir -p "$WORK/Breezeline.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$WORK/icon.png" --out "$WORK/Breezeline.iconset/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size*2))" "$((size*2))" "$WORK/icon.png" --out "$WORK/Breezeline.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$WORK/Breezeline.iconset" -o "$STAGED/Contents/Resources/Breezeline.icns"
cp "$WORK/Breezeline-menu.png" "$STAGED/Contents/Resources/"
cp Sources/Breezeline/Resources/* "$STAGED/Contents/Resources/"
cp LICENSE "$STAGED/Contents/Resources/"
cat > "$STAGED/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Breezeline</string>
<key>CFBundleDisplayName</key><string>Breezeline</string>
<key>CFBundleIdentifier</key><string>com.aaronyanx.Breezeline</string>
<key>CFBundleExecutable</key><string>Breezeline</string>
<key>CFBundleIconFile</key><string>Breezeline</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>${VERSION}</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>LSUIElement</key><true/>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string></array>
<key>NSDesktopFolderUsageDescription</key>
<string>Breezeline watches your screenshot folder to hang new screenshots on the line.</string>
</dict></plist>
PLIST
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/{print $2; exit}')}"
if [ -n "$IDENTITY" ]; then
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$STAGED"
else
  codesign --force --deep --sign - "$STAGED"
fi
mkdir -p build
if [ -e "$APP" ]; then mv "$APP" "$WORK/Previous-Breezeline.app"; fi
ditto "$STAGED" "$APP"
cp "$WORK/icon.png" build/Breezeline-icon.png
echo "Built $APP"
