#!/bin/bash
# 组装 dist/ClipHistory.app（LSUIElement 菜单栏应用，ad-hoc 签名）
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="dist/ClipHistory.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/release/ClipHistoryApp "$APP/Contents/MacOS/ClipHistoryApp"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>ClipHistory</string>
    <key>CFBundleDisplayName</key><string>ClipHistory</string>
    <key>CFBundleIdentifier</key><string>com.crawford.cliphistory</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>ClipHistoryApp</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "✅ 已构建 $APP"
