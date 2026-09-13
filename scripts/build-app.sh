#!/bin/bash
# 组装 dist/ClipboardMaster.app（LSUIElement 菜单栏应用，含应用图标，ad-hoc 签名）
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="dist/ClipboardMaster.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/ClipboardMasterApp "$APP/Contents/MacOS/ClipboardMasterApp"

# 由 assets/icon.png 生成多尺寸 .icns
ICONSET="dist/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 64 128 256 512; do
  sips -z "$size" "$size" assets/icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) assets/icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
sips -z 1024 1024 assets/icon.png --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Clipboard Master</string>
    <key>CFBundleDisplayName</key><string>Clipboard Master</string>
    <key>CFBundleIdentifier</key><string>com.clipboardmaster.app</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>CFBundleShortVersionString</key><string>2.0.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>ClipboardMasterApp</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "✅ 已构建 $APP"
