# ClipHistory — macOS 菜单栏剪贴板历史工具

菜单栏常驻图标，点击即可查看剪贴板历史，点击任意一条立即复制回剪贴板。
纯本地、零第三方依赖的原生 Swift 应用。

## 功能

- **文本 + 图片**：文字、截图等图片内容都会被记录（图片显示缩略图 + 尺寸）
- **最近 200 条**：最新在最前，下拉直接滚动查看全部历史；重启 Mac 后历史仍在
- **点击即复制**：点击任意一条立即写回剪贴板
- **智能去重**：相同内容不重复记录，重新复制会移到最前
- **隐私保护**：自动忽略密码管理器标记的隐藏剪贴板内容（`org.nspasteboard.ConcealedType`）
- **开机自启动**：菜单中可一键开关（需从 .app 运行）
- 无 Dock 图标，仅占一个菜单栏位

## 使用

```bash
./scripts/build-app.sh   # 构建 dist/ClipHistory.app
open dist/ClipHistory.app
```

菜单栏出现 📋 剪贴板图标后，任意复制操作（⌘C）即开始被记录。
想开机自启：点击图标 → 勾选「开机自启动」；然后把 .app 拖到「应用程序」文件夹。

数据位置：`~/Library/Application Support/ClipHistory/`
（`history.json` 索引 + `images/` 图片文件，卸载删除该目录即可彻底清除）

## 开发

```bash
swift build     # 构建
swift test      # 运行全部单元测试（36 个）
```

架构与设计见 `docs/superpowers/`，模块划分：

| 模块 | 职责 |
| --- | --- |
| `ClipHistoryCore/ClipboardContent` | 内容模型 + 边界校验工厂 |
| `ClipHistoryCore/HistoryStore` | 去重、容量淘汰、查询（值语义） |
| `ClipHistoryCore/HistoryPersistence` | JSON + 图片文件持久化，损坏容错 |
| `ClipHistoryCore/PasteboardMonitor` | changeCount 轮询，自我写回忽略 |
| `ClipHistoryCore/SystemPasteboard` | NSPasteboard 适配（薄胶水） |
| `ClipHistoryApp/*` | 状态栏图标 + NSMenu 菜单壳 |
