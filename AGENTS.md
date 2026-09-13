# AGENTS.md — 给 AI Agent 的安装与开发指引

> 你（Agent）收到本仓库后，目标是把 **Clipboard Master** 安装到用户的电脑上。
> 按下文步骤执行即可，无需询问用户技术细节。

## 这是什么

跨平台（macOS + Windows）剪贴板历史工具：托盘/菜单栏图标，点击查看最近 200 条
文本与图片历史，点击任意一条即复制回剪贴板。原生实现，零第三方运行时依赖。

## 安装（按用户系统二选一）

### macOS（≥ 14）

```bash
./install.sh --launch
```

- 依赖：Xcode Command Line Tools（缺失时脚本会提示先跑 `xcode-select --install`）
- 产物：`/Applications/ClipboardMaster.app`，菜单栏出现 📋 图标

### Windows（10/11）

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Launch
```

- 依赖：.NET 8 SDK（脚本经 winget 自动安装）
- 产物：`%LOCALAPPDATA%\Programs\ClipboardMaster\ClipboardMaster.exe`，托盘出现图标

## 安装后验证

1. 让用户复制任意文本（macOS: `echo hello | pbcopy`；Windows: `Set-Clipboard hello`）
2. 等 1-2 秒，点开托盘/菜单栏图标 → 应出现「hello」条目
3. 数据落盘检查：
   - macOS: `~/Library/Application Support/ClipboardMaster/history.json`
   - Windows: `%APPDATA%\ClipboardMaster\history.json`
4. 让用户点击该条目 → 再粘贴出来应得到 `hello`

## 卸载

- macOS: 删除 `/Applications/ClipboardMaster.app`（可选：删除数据目录 `~/Library/Application Support/ClipboardMaster`）
- Windows: `powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall`

## 开发与测试

```bash
# macOS 核心库测试（Swift Testing，39 个）
swift test

# Windows 核心库测试（xUnit，23 个，可跨平台运行）
dotnet test windows/ClipboardMaster.Core.Tests

# macOS 打包
./scripts/build-app.sh
```

## 代码结构

```
Sources/ClipboardMasterCore/    # macOS 核心库（模型/存储/持久化/监控，全测试覆盖）
Sources/ClipboardMasterApp/     # macOS 菜单栏壳（NSStatusItem + NSMenu）
windows/ClipboardMaster.Core/   # Windows 核心库（与 mac 版共享同一 JSON 数据格式）
windows/ClipboardMaster.App/    # Windows 托盘壳（WinForms NotifyIcon + 系统剪贴板事件）
windows/ClipboardMaster.Core.Tests/
assets/icon.png                 # 1024 应用图标源文件
```

## 约定

- 数据格式跨平台一致：`history.json`（version 1，camelCase，ISO8601 无小数秒）
- 核心逻辑改动走 TDD：先写失败测试，再实现
- 密码管理器隐藏标记的内容（macOS `org.nspasteboard.ConcealedType`；Windows
  `ExcludeClipboardContentFromMonitorProcessing` / `CanIncludeInClipboardHistory`）不记录
- 用户数据永远只在本机 `Application Support` / `%APPDATA%`，不上传
