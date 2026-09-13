#!/bin/bash
# 发版：写 VERSION → 提交 → 打 tag → 推送 → 创建 GitHub Release
# 用法: scripts/release.sh <X.Y.Z>
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?用法: scripts/release.sh <X.Y.Z>}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "❌ 版本号格式应为 X.Y.Z"; exit 1; }

if [ -n "$(git status --porcelain)" ]; then
  echo "❌ 工作区不干净，先提交改动"; exit 1
fi

echo "$VERSION" > VERSION
git add VERSION
if [ -n "$(git status --porcelain)" ]; then
  git commit -m "chore: release v$VERSION"
fi
git tag "v$VERSION"
git push origin main --tags
git push origin main || true   # 无新提交时推送报错可忽略
git push origin "v$VERSION"
gh release create "v$VERSION" --title "v$VERSION" --generate-notes --latest
echo "✅ v$VERSION 已发布：https://github.com/crawfordxx/clipboard-master/releases/tag/v$VERSION"
