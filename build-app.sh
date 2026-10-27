#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"
swift build --disable-sandbox --product PetTheAgent

APP="$PROJECT_DIR/dist/Pet the Agent.app"
mkdir -p "$APP/Contents/MacOS"
cp "$PROJECT_DIR/.build/debug/PetTheAgent" "$APP/Contents/MacOS/PetTheAgent"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.eralab.PetTheAgent</string>
  <key>CFBundleName</key><string>Pet the Agent</string>
  <key>CFBundleDisplayName</key><string>Pet the Agent</string>
  <key>CFBundleExecutable</key><string>PetTheAgent</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.16</string>
  <key>CFBundleVersion</key><string>17</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force --sign - "$APP"
echo "$APP"
