#!/bin/bash
# Builds PPPKeeper.app (universal: Apple Silicon + Intel) next to this script.
#   ./build.sh            build only
#   ./build.sh --install  build, copy to /Applications (shows in Launchpad) and open it
set -e
cd "$(dirname "$0")"
APP=PPPKeeper.app
VERSION=1.1.0
TMP=$(mktemp -d)
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos13.0" main.swift -o "$TMP/PPPKeeper-$arch"
done
lipo -create "$TMP"/PPPKeeper-* -output "$APP/Contents/MacOS/PPPKeeper"

swift icon.swift "$TMP/AppIcon.iconset"
iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp keeper.sh "$APP/Contents/Resources/keeper.sh"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>PPPKeeper</string>
  <key>CFBundleDisplayName</key><string>PPPKeeper</string>
  <key>CFBundleIdentifier</key><string>local.pppkeeper</string>
  <key>CFBundleExecutable</key><string>PPPKeeper</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force -s - "$APP" >/dev/null 2>&1 || true
rm -rf "$TMP"
echo "Built $(pwd)/$APP"

if [ "$1" = "--install" ]; then
  pkill -x PPPKeeper 2>/dev/null || true
  rm -rf "/Applications/$APP"
  cp -R "$APP" /Applications/
  open "/Applications/$APP"
  echo "Installed to /Applications/$APP"
fi
