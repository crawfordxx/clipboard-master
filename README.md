# Clipboard Master 📋

跨平台（macOS + Windows）开源剪贴板历史工具。托盘/菜单栏常驻图标，
点击查看最近 200 条文本与图片历史，点击任意一条立即复制回剪贴板。

**原生实现**：macOS 版为 Swift 菜单栏应用，Windows 版为 C# WinForms 托盘应用，
零第三方运行时依赖。**不提供安装包**——把仓库交给你的 AI Agent 一条命令装好，
或自己跑一条安装脚本。

## 功能

- **文本 + 图片**：文字、截图都会记录，图片条目带缩略图与尺寸
- **完整历史窗口**：搜索过滤、双击/回车复制、单条删除、清空；相对时间展示
- **下拉菜单图片大预览**：菜单中图片条目显示 48pt 预览，并可一键在 Finder / 资源管理器中定位落盘文件
- **最近 200 条**：最新在最前，直接滚动查看全部；重启后历史仍在
- **应用内自更新**：自动检查 GitHub 新版本，一键拉取源码重新构建并自动重启（历史数据不丢）；也可手动「检查更新」
- **智能去重**：相同内容不重复记录，重新复制自动移到最前
- **隐私优先**：密码管理器标记的隐藏剪贴板内容不记录；数据只在本机（唯一联网请求是 GitHub 版本查询）
- **开机自启动**：菜单中一键开关
- macOS 无 Dock 图标仅占菜单栏位；Windows 常驻系统托盘

## 安装

### 方式一：交给 AI Agent（推荐）

把这个仓库地址发给你的 Agent（Claude Code / Codex / Cursor / pi 等任一）：

> 帮我安装这个仓库里的 Clipboard Master：https://github.com/<你的用户名>/clipboard-master

仓库内置 [AGENTS.md](AGENTS.md)，Agent 会自动识别系统并完成安装与验证。

### 方式二：自己动手

**macOS**（≥ 14，需 Xcode Command Line Tools）：

```bash
git clone https://github.com/<你的用户名>/clipboard-master
cd clipboard-master
./install.sh --launch
```

**Windows**（10/11，脚本会经 winget 自动装 .NET 8 SDK）：

```powershell
git clone https://github.com/<你的用户名>/clipboard-master
cd clipboard-master
powershell -ExecutionPolicy Bypass -File install.ps1 -Launch
```

数据位置（卸载后想彻底清除就删这个目录）：

- macOS: `~/Library/Application Support/ClipboardMaster/`
- Windows: `%APPDATA%\ClipboardMaster/`

两平台共享同一 `history.json` 数据格式，格式规格见 AGENTS.md。

## 开发

```bash
swift test                                # macOS 核心库（53 个测试）
dotnet test windows/ClipboardMaster.Core.Tests   # Windows 核心库（31 个测试，跨平台可跑）
./scripts/build-app.sh                    # macOS .app 打包（含图标与版本号）
```

## 发版与更新

- 版本唯一源：仓库根 `VERSION` 文件；构建时打进 mac Info.plist 与 Windows 安装目录
- 发版：`scripts/release.sh X.Y.Z` → 自动提交、打 tag、创建 GitHub Release
- 用户端：应用启动及每 24h 自动静默检查；发现新版本后菜单出现「🆕 更新」入口，
  自动执行 `git checkout 新tag → 重新安装 → 重启`；源码克隆丢失或有本地改动时
  安全回退为打开 Releases 页

详见 [AGENTS.md](AGENTS.md) 的代码结构说明与 [docs/superpowers/](docs/superpowers/)
下的设计文档与实现计划。

## License

[MIT](LICENSE)
