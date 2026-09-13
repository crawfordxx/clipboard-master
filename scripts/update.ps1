# 应用内自更新脚本（由应用拉起，应用会被本脚本重启）
# 用法: powershell -File update.ps1 -CloneDir <克隆路径> -Tag <版本号，如 2.2.0>
param(
    [Parameter(Mandatory = $true)][string]$CloneDir,
    [Parameter(Mandatory = $true)][string]$Tag
)
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:APPDATA 'ClipboardMaster\update.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
function L($m) { Add-Content $log "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $m" }

Push-Location $CloneDir
try {
    if (-not (Test-Path "$CloneDir\.git")) { L "❌ 非 git 克隆目录: $CloneDir"; exit 1 }
    $dirty = git status --porcelain
    if ($dirty) { L "❌ 工作区有本地改动，取消自动更新"; exit 2 }

    L "⬇️  拉取 v$Tag …"
    git fetch origin --tags --force
    git rev-parse "refs/tags/v$Tag" *> $null
    if ($LASTEXITCODE -ne 0) { L "❌ 远端不存在 tag v$Tag"; exit 3 }
    git checkout -f "refs/tags/v$Tag"
}
finally { Pop-Location }

L "🔨 重新构建安装并启动 …"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $CloneDir 'install.ps1') -Launch
L "✅ 已更新到 v$Tag"
