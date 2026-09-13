#!/bin/bash
# Clipboard Master · macOS 安装脚本（Agent 可直接执行）
# 用法: ./install.sh [--launch]   （--launch 安装后立即启动）
set -euo pipefail
cd "$(dirname "$0")"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ 此脚本仅用于 macOS；Windows 请运行: powershell -ExecutionPolicy Bypass -File install.ps1"
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "❌ 未检测到 Swift 工具链，先安装 Xcode Command Line Tools:"
  echo "   xcode-select --install"
  exit 1
fi

echo "🔨 构建中..."
./scripts/build-app.sh

DEST="/Applications/ClipboardMaster.app"
rm -rf "$DEST"
cp -R dist/ClipboardMaster.app "$DEST"
echo "✅ 已安装到 $DEST"

if [[ "${1:-}" == "--launch" ]]; then
  open "$DEST"
  echo "🚀 已启动：菜单栏顶部出现 📋 图标即成功"
else
  echo "💡 启动: open $DEST （启动后可在菜单中开启「开机自启动」）"
fi
