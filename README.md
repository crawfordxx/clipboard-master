# Clipboard Master 📋

跨平台（macOS + Windows）开源剪贴板历史工具。托盘/菜单栏常驻图标，
点击查看最近 200 条文本与图片历史，点击任意一条立即复制回剪贴板。

**原生实现**：macOS 版为 Swift 菜单栏应用，Windows 版为 C# WinForms 托盘应用，
零第三方运行时依赖。**不提供安装包**——把仓库交给你的 AI Agent 一条命令装好，
或自己跑一条安装脚本。

## 功能

- **文本 + 图片**：文字、截图都会记录，图片条目带缩略图与尺寸
- **最近 200 条**：最新在最前，下拉/点开直接滚动查看全部；重启后历史仍在
- **点击即复制**：任意一条点一下就写回剪贴板
- **智能去重**：相同内容不重复记录，重新复制自动移到最前
- **隐私优先**：密码管理器标记的隐藏剪贴板内容不记录；数据只在本机
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
swift test                                # macOS 核心库（39 个测试）
dotnet test windows/ClipboardMaster.Core.Tests   # Windows 核心库（23 个测试，跨平台可跑）
./scripts/build-app.sh                    # macOS .app 打包（含图标）
```

详见 [AGENTS.md](AGENTS.md) 的代码结构说明与 [docs/superpowers/](docs/superpowers/)
下的设计文档与实现计划。

## License

[MIT](LICENSE)
