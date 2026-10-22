#!/bin/bash
# Builds PPPKeeper.app next to this script.
set -e
cd "$(dirname "$0")"
APP=PPPKeeper.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O main.swift -o "$APP/Contents/MacOS/PPPKeeper"
cp keeper.sh "$APP/Contents/Resources/keeper.sh"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>PPPKeeper</string>
  <key>CFBundleIdentifier</key><string>local.pppkeeper</string>
  <key>CFBundleExecutable</key><string>PPPKeeper</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force -s - "$APP" >/dev/null 2>&1 || true
echo "Built $(pwd)/$APP"
