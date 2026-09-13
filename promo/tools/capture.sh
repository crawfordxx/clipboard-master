#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT="${1:-$ROOT/../..}"
IMAGE="${2:-$PROJECT/assets/brand/pony.png}"
PROJECT="$(cd "$PROJECT" && pwd)"
IMAGE="$(cd "$(dirname "$IMAGE")" && pwd)/$(basename "$IMAGE")"
OUTPUT="$ROOT/../qa/native"
APP="$ROOT/../qa/PonyCapture.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUTPUT"
cd "$PROJECT"
swift build >/dev/null
BUILD=$(swift build --show-bin-path)
swiftc -I "$BUILD/Modules" "$BUILD"/ClipboardMasterCore.build/*.swift.o Sources/ClipboardMasterApp/MenuPanelView.swift Sources/ClipboardMasterApp/UpdateChecker.swift Sources/ClipboardMasterApp/HistoryView.swift Sources/ClipboardMasterApp/HistoryViewModel.swift "$ROOT/main.swift" -o "$APP/Contents/MacOS/PonyCapture"
cp "$IMAGE" "$APP/Contents/Resources/BrandMark.png"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>PonyCapture</string><key>CFBundleIdentifier</key><string>com.clipboardmaster.pony-capture</string><key>LSBackgroundOnly</key><true/></dict></plist>
PLIST
"$APP/Contents/MacOS/PonyCapture" "$ROOT" "$OUTPUT" "$IMAGE"
