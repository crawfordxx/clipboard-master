# Clipboard Master · Windows 安装脚本（Agent 可直接执行）
# 用法:
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Launch   # 安装并启动
#   powershell -ExecutionPolicy Bypass -File install.ps1           # 仅安装
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
param(
    [switch]$Launch,
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
$InstallDir = "$env:LOCALAPPDATA\Programs\ClipboardMaster"
$ShortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Clipboard Master.lnk"
$RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

if ($Uninstall) {
    Write-Host "🧹 卸载 Clipboard Master..."
    $existing = Get-Process -Name 'ClipboardMaster' -ErrorAction SilentlyContinue
    if ($existing) { $existing | Stop-Process -Force }
    if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
    if (Test-Path $ShortcutPath) { Remove-Item $ShortcutPath -Force }
    Write-Host "✅ 已卸载（历史数据保留在 %APPDATA%\ClipboardMaster，可手动删除）"
    exit 0
}

# 1. 检查 .NET 8 SDK（缺失则经 winget 安装）
$sdkOk = $false
try {
    $null = dotnet --list-sdks 2>$null | Select-String '^8\.'
    $sdkOk = ($LASTEXITCODE -eq 0) -or $null -ne ($null)
} catch {}
if (-not $sdkOk -and -not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host "📦 安装 .NET 8 SDK（经 winget）..."
    winget install --id Microsoft.DotNet.SDK.8 -e --accept-source-agreements --accept-package-agreements
}

# 2. 发布自包含单文件 exe（无需用户机器装运行时）
Write-Host "🔨 构建中..."
$publishOut = "$PSScriptRoot\windows\publish"
dotnet publish "$PSScriptRoot\windows\ClipboardMaster.App" -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -o $publishOut
if ($LASTEXITCODE -ne 0) { throw "构建失败（exit $LASTEXITCODE）" }

# 3. 停止运行中的实例（exe 被占用时无法覆盖）
$running = Get-Process -Name 'ClipboardMaster' -ErrorAction SilentlyContinue
if ($running) { $running | Stop-Process -Force; Start-Sleep -Milliseconds 500 }

# 4. 安装到用户目录
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item "$publishOut\ClipboardMaster.exe" $InstallDir -Force
Copy-Item "$PSScriptRoot\windows\ClipboardMaster.App\app.ico" $InstallDir -Force
Copy-Item "$PSScriptRoot\VERSION" $InstallDir -Force

# 5. 开始菜单快捷方式
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($ShortcutPath)
$shortcut.TargetPath = "$InstallDir\ClipboardMaster.exe"
$shortcut.IconLocation = "$InstallDir\app.ico"
$shortcut.Save()

# 6. 写入来源清单：自更新时定位源码克隆与版本
$dataDir = "$env:APPDATA\ClipboardMaster"
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
$version = if (Test-Path "$PSScriptRoot\VERSION") { (Get-Content "$PSScriptRoot\VERSION" -Raw).Trim() } else { 'unknown' }
$source = @{ repo = 'https://github.com/crawfordxx/clipboard-master'; clonePath = $PSScriptRoot; version = $version }
$source | ConvertTo-Json -Compress | Set-Content "$dataDir\source.json"

Write-Host "✅ 已安装到 $InstallDir (v$version)"

if ($Launch) {
    Start-Process "$InstallDir\ClipboardMaster.exe"
    Write-Host "🚀 已启动：系统托盘出现图标即成功（可能需点击托盘 ^ 展开箭头）"
} else {
    Write-Host "💡 启动: $InstallDir\ClipboardMaster.exe（托盘右键菜单中可开启「开机自启动」）"
}
