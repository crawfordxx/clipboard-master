# ClipHistory — macOS 剪贴板历史工具 设计文档

日期：2026-09-13
状态：已与用户确认方案（原生 Swift 菜单栏应用）

## 1. 背景与目标

为本机 macOS 开发一个剪贴板历史工具：菜单栏常驻图标，点击后下拉显示剪贴板记录，
点击任意一条即可复制回剪贴板。纯本地工具，无网络功能。

## 2. 需求（用户已确认）

1. **内容类型**：文本 + 图片（截图等）
2. **容量与持久化**：保留最近 200 条，重启 Mac 后历史仍在（本地存储）
3. **交互**：
   - 顶部菜单栏常驻图标（无 Dock 图标）
   - 点击图标 → 下拉列表，最新在最上，首屏约见 10 条
   - 列表可直接继续滚动查看全部 200 条历史（不另开窗口）
   - 点击任意一条 → 立即复制回剪贴板（菜单自动收起）
   - 底部附「清空历史」「开机自启动」「退出」
4. **安全细节**：自动忽略密码管理器标记的隐藏剪贴板内容（`org.nspasteboard.ConcealedType`）

## 3. 方案选型

**原生 Swift 菜单栏应用**（已确认）：`NSStatusItem` + `NSMenu`，系统自带工具链，
零第三方依赖，内存占用极低。开源工具 Maccy 的同款架构，成熟可靠。

## 4. 架构

Swift Package，两个 target，核心逻辑与 UI 壳分离以便测试：

```
clipboard-history/
├── Package.swift
├── scripts/build-app.sh          # 组装 .app 包
├── Sources/
│   ├── ClipHistoryCore/          # 核心库（全部单元测试覆盖）
│   │   ├── ClipboardContent.swift     # 内容模型 + 校验工厂
│   │   ├── ClipboardEntry.swift       # 历史条目（id + 时间 + 内容）
│   │   ├── HistoryLimits.swift        # 常量集中管理
│   │   ├── HistoryStore.swift         # 去重/淘汰/查询（值语义）
│   │   ├── HistoryPersistence.swift   # JSON 索引 + 图片文件 读写/校验/清理
│   │   ├── PreviewFormatter.swift     # 菜单标题/悬浮提示格式化
│   │   ├── PasteboardReading.swift    # 粘贴板抽象协议
│   │   ├── PasteboardMonitor.swift    # changeCount 轮询逻辑
│   │   └── SystemPasteboard.swift     # NSPasteboard 适配器（薄胶水层）
│   └── ClipHistoryApp/          # 应用壳（手动/冒烟验证）
│       ├── main.swift                 # 入口，LSUIElement
│       ├── AppDelegate.swift
│       ├── StatusItemController.swift # 状态栏图标 + 菜单刷新 + 定时轮询
│       └── MenuFactory.swift          # NSMenu 构建
└── Tests/ClipHistoryCoreTests/  # Swift Testing 单元测试
```

## 5. 关键设计

### 5.1 剪贴板监听

macOS 无剪贴板变更通知。`PasteboardMonitor` 每 0.5s 对比
`NSPasteboard.changeCount`，变化时通过 `PasteboardReading` 协议读取内容。
用户点击历史条目写回剪贴板时，同步标记忽略该次 changeCount，避免自我回环记录。

### 5.2 数据模型

- `ClipboardContent`：`text(String)` 或 `image(imageData, pixelWidth, pixelHeight)`
  - 工厂方法做边界校验：文本 trim 后非空、截断上限 100k 字符；图片数据非空、尺寸为正
  - 相等性：文本按内容；图片按数据字节
- `ClipboardEntry`：`id: UUID` + `capturedAt: Date` + `content`
- `HistoryStore`（struct，值语义，满足不可变要求）：
  - `insert`：新内容插到最前；若与任意现存条目内容相同则先移除旧条目（去重保新鲜）
  - 超过 200 条自动淘汰最旧
  - `removeAll()`、`entry(id:)`

### 5.3 持久化

位置：`~/Library/Application Support/ClipHistory/`
- `history.json`：版本化索引（DTO 显式校验后转领域模型）
- `images/<uuid>.png`：图片文件
- 写入原子（`.atomic`），保存后清理孤儿图片文件
- 读取容错：目录/文件不存在 → 空历史；JSON 损坏 → 空历史并备份损坏文件；
  单条目字段非法或图片文件丢失 → 丢弃该条，不影响其余

### 5.4 菜单

- 文本条目：单行预览（折叠空白，60 字符截断），tooltip 显示时间 + 200 字符预览
- 图片条目：缩略图（约 20pt）+ 标题「图片 W×H」，tooltip 同上
- 空历史显示禁用项「暂无记录」
- 底部：分隔线 + 清空历史 / 开机自启动（SMAppService）/ 退出

### 5.5 常量（HistoryLimits）

容量 200；轮询 0.5s；文本存储上限 100,000 字符；菜单预览 60 字符；tooltip 200 字符。

## 6. 错误处理

- 持久化保存失败：stderr 记录上下文，内存历史不受影响（下次成功覆盖）
- 读取损坏：备份后从空开始，不崩溃
- 开机自启动注册失败（SMAppService）：stderr 记录，菜单勾选状态回退
- 所有 UI 操作在主线程；粘贴板读写失败返回 nil 并跳过该次

## 7. 测试策略（TDD，目标覆盖 ≥80% 核心库）

- 单元测试（Swift Testing，先写测试看失败再实现）：
  内容工厂校验、预览格式化、HistoryStore 去重/淘汰、持久化读写/容错/清理、
  Monitor 轮询/自我忽略（用 Fake 粘贴板，不碰真实 NSPasteboard）
- `SystemPasteboard` 与 App 壳为薄胶水层，冒烟验证：
  `build-app.sh` → `open` → `pbcopy` 写入 → 检查 history.json 捕获到内容 → 退出

## 8. 非目标（YAGNI）

全局快捷键、iCloud 同步、富文本/文件类型、搜索框、多设备、菜单栏以外 UI。
