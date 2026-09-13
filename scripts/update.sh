#!/bin/bash
# 应用内自更新脚本（由应用拉起，应用会被本脚本重启）
# 用法: update.sh <cloneDir> <latestVersion>
set -euo pipefail

CLONE_DIR="$1"
VERSION="$2"
APP="/Applications/ClipboardMaster.app"
LOG_DIR="$HOME/Library/Application Support/ClipboardMaster"

log() { echo "[$(date '+%F %T')] $*" >> "$LOG_DIR/update.log"; }

cd "$CLONE_DIR"
if [ ! -d .git ]; then log "❌ 非 git 克隆目录: $CLONE_DIR"; exit 1; fi
if [ -n "$(git status --porcelain)" ]; then log "❌ 工作区有本地改动，取消自动更新（可手动处理）"; exit 2; fi

log "⬇️  拉取 v$VERSION …"
git fetch origin --tags --force
if ! git rev-parse "refs/tags/v$VERSION" >/dev/null 2>&1; then
  log "❌ 远端不存在 tag v$VERSION"; exit 3
fi
git checkout -f "refs/tags/v$VERSION"

log "🔨 重新构建安装 …"
./install.sh

log "🔄 重启应用 …"
pkill -f ClipboardMasterApp || true
sleep 1
open "$APP"
log "✅ 已更新到 v$VERSION"
