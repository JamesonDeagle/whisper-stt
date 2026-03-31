#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP="Murmur.app"

echo "Building Murmur..."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release

echo "Creating app bundle..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/Murmur "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp Assets/AppIcon.icns "$APP/Contents/Resources/"

# Code sign with stable identity so Accessibility permission persists across rebuilds
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [ -n "$IDENTITY" ]; then
    echo "Signing with: $IDENTITY"
    codesign --force --deep --sign "$IDENTITY" "$APP"
else
    echo "Warning: No signing identity found. Accessibility permission will reset on each rebuild."
    codesign --force --deep --sign - "$APP"
fi

echo "Installing to /Applications..."
pkill -f "Murmur.app/Contents/MacOS/Murmur" 2>/dev/null || true
sleep 0.3
rm -rf /Applications/Murmur.app
cp -R "$APP" /Applications/Murmur.app

echo "Done: /Applications/Murmur.app"
echo "Run: open /Applications/Murmur.app"
