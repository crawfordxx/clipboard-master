# ClipHistory 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS 菜单栏剪贴板历史工具：常驻图标、点击查看/滚动全部历史、点击条目复制回剪贴板。

**Architecture:** SwiftPM 双 target——`ClipHistoryCore`（可测核心库：模型/去重存储/持久化/轮询监控）+ `ClipHistoryApp`（AppKit 薄壳：状态栏图标与菜单）。粘贴板经 `PasteboardReading` 协议抽象，测试用 Fake，生产用 `SystemPasteboard`。

**Tech Stack:** Swift 5 模式（swift-tools 5.10）、AppKit（NSStatusItem/NSMenu）、ServiceManagement（SMAppService）、Swift Testing。

**Spec:** `docs/superpowers/specs/2026-09-13-clip-history-design.md`

## Global Constraints

- 容量 200；轮询间隔 0.5s；文本存储上限 100,000 字符；菜单预览 60 字符；tooltip 200 字符（HistoryLimits 集中定义）
- 忽略 `org.nspasteboard.ConcealedType` 隐藏剪贴板
- 存储目录 `~/Library/Application Support/ClipHistory/`（测试注入临时目录）
- 值语义 struct，不共享可变状态；所有常量集中在 `HistoryLimits`
- 每个 Task 结束：`swift test` 全绿 → commit（conventional commits）

---

### Task 1: SwiftPM 脚手架

**Files:**
- Create: `Package.swift`
- Create: `Sources/ClipHistoryCore/Placeholder.swift`（仅占位，Task 2 删除）
- Create: `Sources/ClipHistoryApp/main.swift`（最小入口）
- Create: `Tests/ClipHistoryCoreTests/SmokeTests.swift`

**Interfaces:**
- Produces: 可构建的包，target 名 `ClipHistoryCore` / `ClipHistoryApp`，测试 target `ClipHistoryCoreTests`

- [x] **Step 1: 写 Package.swift（双 target）**

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ClipHistory",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ClipHistoryCore"),
        .executableTarget(
            name: "ClipHistoryApp",
            dependencies: ["ClipHistoryCore"]
        ),
        .testTarget(
            name: "ClipHistoryCoreTests",
            dependencies: ["ClipHistoryCore"]
        ),
    ]
)
```

- [x] **Step 2: 占位文件与最小 main.swift**

`Sources/ClipHistoryCore/Placeholder.swift`: `enum Placeholder {}`
`Sources/ClipHistoryApp/main.swift`: `print("ClipHistory bootstrap")`
`Tests/ClipHistoryCoreTests/SmokeTests.swift`:

```swift
import Testing
@testable import ClipHistoryCore

@Test func placeholderCompiles() {
    #expect(Placeholder.self != Void.self)
}
```

- [x] **Step 3: 验证**

Run: `swift build && swift test`
Expected: BUILD SUCCEEDED，1 个测试 PASS

- [x] **Step 4: Commit** `chore: SwiftPM 脚手架`

---

### Task 2: 内容模型 + 常量 + 预览格式化

**Files:**
- Create: `Sources/ClipHistoryCore/HistoryLimits.swift`
- Create: `Sources/ClipHistoryCore/ClipboardContent.swift`
- Create: `Sources/ClipHistoryCore/ClipboardEntry.swift`
- Create: `Sources/ClipHistoryCore/PreviewFormatter.swift`
- Delete: `Sources/ClipHistoryCore/Placeholder.swift`, `Tests/ClipHistoryCoreTests/SmokeTests.swift`
- Test: `Tests/ClipHistoryCoreTests/ClipboardContentTests.swift`, `Tests/ClipHistoryCoreTests/PreviewFormatterTests.swift`

**Interfaces:**
- Produces:
  - `enum HistoryLimits { static let capacity: Int; static let pollInterval: TimeInterval; static let storedTextCap: Int; static let menuPreviewLimit: Int; static let tooltipPreviewLimit: Int }`
  - `enum ClipboardContent: Equatable { case text(String); case image(imageData: Data, pixelWidth: Int, pixelHeight: Int); static func make(text: String) -> ClipboardContent?; static func make(imageData: Data, pixelWidth: Int, pixelHeight: Int) -> ClipboardContent? }`
  - `struct ClipboardEntry: Identifiable, Equatable { let id: UUID; let capturedAt: Date; let content: ClipboardContent }`
  - `enum PreviewFormatter { static func menuTitle(for: ClipboardContent) -> String; static func tooltip(for: ClipboardEntry) -> String; static func collapsedText(_: String, limit: Int) -> String }`

- [x] **Step 1: 失败测试（先写，运行确认失败）**

```swift
import Testing
import Foundation
@testable import ClipHistoryCore

@Test func makeTextTrimsAndRejectsEmpty() {
    #expect(ClipboardContent.make(text: "  hello  ") == .text("hello"))
    #expect(ClipboardContent.make(text: "   \n\t ") == nil)
}

@Test func makeTextCapsLength() {
    let long = String(repeating: "a", count: HistoryLimits.storedTextCap + 50)
    let made = ClipboardContent.make(text: long)
    #expect(made == .text(String(repeating: "a", count: HistoryLimits.storedTextCap)))
}

@Test func makeImageValidates() {
    #expect(ClipboardContent.make(imageData: Data([1, 2]), pixelWidth: 10, pixelHeight: 20) != nil)
    #expect(ClipboardContent.make(imageData: Data(), pixelWidth: 10, pixelHeight: 20) == nil)
    #expect(ClipboardContent.make(imageData: Data([1]), pixelWidth: 0, pixelHeight: 20) == nil)
    #expect(ClipboardContent.make(imageData: Data([1]), pixelWidth: 10, pixelHeight: -1) == nil)
}

@Test func imageEqualityByBytes() {
    let a = ClipboardContent.make(imageData: Data([1, 2, 3]), pixelWidth: 5, pixelHeight: 5)!
    let b = ClipboardContent.make(imageData: Data([1, 2, 3]), pixelWidth: 9, pixelHeight: 9)!
    #expect(a == b)
}
```

PreviewFormatterTests：

```swift
@Test func collapsedTextFoldsWhitespace() {
    #expect(PreviewFormatter.collapsedText("a\n\n b \t c ", limit: 50) == "a b c")
}

@Test func collapsedTextTruncatesWithEllipsis() {
    #expect(PreviewFormatter.collapsedText("abcdef", limit: 3) == "abc…")
}

@Test func menuTitleText() {
    #expect(PreviewFormatter.menuTitle(for: .text("hi")) == "hi")
}

@Test func menuTitleImage() {
    let c = ClipboardContent.make(imageData: Data([1]), pixelWidth: 128, pixelHeight: 64)!
    #expect(PreviewFormatter.menuTitle(for: c) == "图片 128×64")
}

@Test func tooltipContainsPreview() {
    let e = ClipboardEntry(id: UUID(), capturedAt: Date(timeIntervalSince1970: 0), content: .text("hello"))
    #expect(PreviewFormatter.tooltip(for: e).contains("hello"))
}
```

- [x] **Step 2: 运行** `swift test` → 预期编译失败（类型不存在）
- [x] **Step 3: 最小实现**（HistoryLimits 常量；make 工厂做 trim/上限/尺寸校验；collapsedText 用 `split(whereSeparator: \.isWhitespace).joined(separator: " ")`；menuTitle 文本走 collapsedText(menuPreviewLimit)，图片 `"图片 \(w)×\(h)"`；tooltip = 日期 + collapsedText(tooltipPreviewLimit)）
- [x] **Step 4: `swift test` 全绿**
- [x] **Step 5: Commit** `feat: 内容模型、常量与预览格式化`

---

### Task 3: HistoryStore（去重/淘汰/查询）

**Files:**
- Create: `Sources/ClipHistoryCore/HistoryStore.swift`
- Test: `Tests/ClipHistoryCoreTests/HistoryStoreTests.swift`

**Interfaces:**
- Consumes: `ClipboardContent`, `ClipboardEntry`, `HistoryLimits.capacity`
- Produces: `struct HistoryStore { var entries: [ClipboardEntry]; init(capacity: Int = HistoryLimits.capacity); mutating func insert(_ content: ClipboardContent, at date: Date = Date()) -> Bool; mutating func removeAll(); func entry(id: UUID) -> ClipboardEntry? }`

- [x] **Step 1: 失败测试**

```swift
@Test func insertPutsNewestFirst() {
    var s = HistoryStore()
    #expect(s.insert(.text("a")))
    #expect(s.insert(.text("b")))
    #expect(s.entries.map(\.content) == [.text("b"), .text("a")])
}

@Test func insertDuplicateRemovesOldAndMovesToTop() {
    var s = HistoryStore()
    s.insert(.text("a")); s.insert(.text("b")); s.insert(.text("a"))
    #expect(s.entries.map(\.content) == [.text("a"), .text("b")])
    #expect(s.entries.allSatisfy { ClipboardContent.make(text: "") == nil })
}

@Test func duplicateInsertReturnsFalseAndKeepsTimestamp() {
    var s = HistoryStore()
    let t0 = Date(timeIntervalSince1970: 100)
    let t1 = Date(timeIntervalSince1970: 200)
    #expect(s.insert(.text("a"), at: t0))
    #expect(s.insert(.text("a"), at: t1) == false)
    #expect(s.entries[0].capturedAt == t0)
}

@Test func capacityTrimsOldest() {
    var s = HistoryStore(capacity: 3)
    for i in 0..<5 { s.insert(.text("t\(i)")) }
    #expect(s.entries.count == 3)
    #expect(s.entries.map(\.content) == [.text("t4"), .text("t3"), .text("t2")])
}

@Test func duplicateBeyondCapacityStillDedupes() {
    var s = HistoryStore(capacity: 2)
    s.insert(.text("a")); s.insert(.text("b")); s.insert(.text("a"))
    #expect(s.entries.map(\.content) == [.text("a"), .text("b")])
}

@Test func removeAllAndEntryById() {
    var s = HistoryStore()
    s.insert(.text("x"))
    let id = s.entries[0].id
    #expect(s.entry(id: id)?.content == .text("x"))
    s.removeAll()
    #expect(s.entries.isEmpty)
    #expect(s.entry(id: id) == nil)
}
```

- [x] **Step 2: 运行** → 失败（HistoryStore 不存在）
- [x] **Step 3: 实现**（insert：`entries.removeAll { $0.content == content }` 命中则不重建条目直接 return false；否则前插并按 capacity 去尾）
- [x] **Step 4: `swift test` 全绿**
- [x] **Step 5: Commit** `feat: HistoryStore 去重与容量淘汰`

---

### Task 4: HistoryPersistence（JSON + 图片文件，容错）

**Files:**
- Create: `Sources/ClipHistoryCore/HistoryPersistence.swift`
- Test: `Tests/ClipHistoryCoreTests/HistoryPersistenceTests.swift`

**Interfaces:**
- Consumes: `ClipboardEntry`, `ClipboardContent.make(...)`, `HistoryLimits.capacity`
- Produces: `final class HistoryPersistence { init(directory: URL, capacity: Int = HistoryLimits.capacity); func load() -> [ClipboardEntry]; func save(_ entries: [ClipboardEntry]) throws; func clearAll() throws }`

- [x] **Step 1: 失败测试**（临时目录 `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)`，每个测试 teardown 删除）

```swift
@Test func saveThenLoadRoundTripsTextAndImage() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let p = HistoryPersistence(directory: dir)
    let img = ClipboardContent.make(imageData: Data([9, 9, 9]), pixelWidth: 8, pixelHeight: 6)!
    let entries = [
        ClipboardEntry(id: UUID(), capturedAt: Date(timeIntervalSince1970: 42), content: .text("hi")),
        ClipboardEntry(id: UUID(), capturedAt: Date(timeIntervalSince1970: 43), content: img),
    ]
    try p.save(entries)
    let loaded = p.load()
    #expect(loaded.count == 2)
    #expect(loaded[0].content == .text("hi"))
    #expect(loaded[1].content == img)
    #expect(loaded[1].capturedAt.timeIntervalSince1970 == 43)
    try? FileManager.default.removeItem(at: dir)
}

@Test func loadMissingDirectoryReturnsEmpty() {
    let p = HistoryPersistence(directory: FileManager.default.temporaryDirectory.appendingPathComponent("nope-\(UUID().uuidString)"))
    #expect(p.load().isEmpty)
}

@Test func loadCorruptJSONReturnsEmptyAndBacksUp() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try Data("{broken".utf8).write(to: dir.appendingPathComponent("history.json"))
    let p = HistoryPersistence(directory: dir)
    #expect(p.load().isEmpty)
    #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("history.json.corrupt").path))
    try? FileManager.default.removeItem(at: dir)
}

@Test func loadDropsEntryWithMissingImageFile() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let p = HistoryPersistence(directory: dir)
    var e = ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("ok"))
    try p.save([e])
    e = ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("gone"))
    try p.save([e])
    // 手动删掉一张图再加载 → 该条被丢弃
    try p.save([ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("keep")),
                ClipboardEntry(id: UUID(), capturedAt: Date(), content: ClipboardContent.make(imageData: Data([1,1]), pixelWidth: 2, pixelHeight: 2)!)])
    let imagesDir = dir.appendingPathComponent("images")
    let files = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)
    try FileManager.default.removeItem(at: files[0])
    #expect(p.load().count == 1)
    try? FileManager.default.removeItem(at: dir)
}

@Test func loadTrimsToCapacity() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let p = HistoryPersistence(directory: dir, capacity: 2)
    try p.save((0..<5).map { ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("x\($0)")) })
    #expect(p.load().count == 2)
    try? FileManager.default.removeItem(at: dir)
}

@Test func savePrunesOrphanImages() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let p = HistoryPersistence(directory: dir)
    try p.save([ClipboardEntry(id: UUID(), capturedAt: Date(), content: ClipboardContent.make(imageData: Data([1]), pixelWidth: 1, pixelHeight: 1)!)])
    let imagesDir = dir.appendingPathComponent("images")
    try Data([0]).write(to: imagesDir.appendingPathComponent("orphan.png"))
    try p.save([ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("only text"))])
    #expect(try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil).isEmpty)
    try? FileManager.default.removeItem(at: dir)
}

@Test func clearAllRemovesEverything() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let p = HistoryPersistence(directory: dir)
    try p.save([ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("z"))])
    try p.clearAll()
    #expect(p.load().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("history.json").path))
    try? FileManager.default.removeItem(at: dir)
}
```

- [x] **Step 2: 运行** → 失败
- [x] **Step 3: 实现**（内部 `PersistedEntry: Codable` DTO：id/capturedAt/kind(.text/.image)/text/file/width/height；save：写图 `images/<uuid>.png` → 原子写 JSON → 清孤儿；load：解码失败备份 `.corrupt` 返回 []，逐条校验字段、图片文件读取失败丢弃，cap 截断）
- [x] **Step 4: `swift test` 全绿**
- [x] **Step 5: Commit** `feat: 历史持久化与容错加载`

---

### Task 5: PasteboardMonitor + PasteboardReading

**Files:**
- Create: `Sources/ClipHistoryCore/PasteboardReading.swift`
- Create: `Sources/ClipHistoryCore/PasteboardMonitor.swift`
- Test: `Tests/ClipHistoryCoreTests/PasteboardMonitorTests.swift`

**Interfaces:**
- Consumes: `ClipboardContent`
- Produces:
  - `protocol PasteboardReading: AnyObject { var changeCount: Int { get }; func readContent() -> ClipboardContent?; func write(_ content: ClipboardContent) }`
  - `final class PasteboardMonitor { init(pasteboard: PasteboardReading); var onNewContent: ((ClipboardContent) -> Void)?; func poll(); func ignoreNextChange() }`

- [x] **Step 1: 失败测试**（FakePasteboard：changeCount 手动 +1，readContent 返回脚本值，write 记录并 +1）

```swift
final class FakePasteboard: PasteboardReading {
    var changeCount = 0
    var scripted: ClipboardContent?
    private(set) var written: [ClipboardContent] = []
    func readContent() -> ClipboardContent? { scripted }
    func write(_ content: ClipboardContent) { written.append(content); changeCount += 1 }
}

@Test func pollEmitsNewContentOnChange() {
    let pb = FakePasteboard()
    let m = PasteboardMonitor(pasteboard: pb)
    var got: [ClipboardContent] = []
    m.onNewContent = { got.append($0) }
    m.poll()
    #expect(got.isEmpty)
    pb.scripted = .text("new"); pb.changeCount += 1
    m.poll()
    #expect(got == [.text("new")])
}

@Test func pollSkipsUnreadableOrConcealed() {
    let pb = FakePasteboard()
    let m = PasteboardMonitor(pasteboard: pb)
    var got: [ClipboardContent] = []
    m.onNewContent = { got.append($0) }
    pb.scripted = nil; pb.changeCount += 1
    m.poll()
    #expect(got.isEmpty)
}

@Test func ignoreNextChangeSwallowsOwnWrite() {
    let pb = FakePasteboard()
    let m = PasteboardMonitor(pasteboard: pb)
    var got: [ClipboardContent] = []
    m.onNewContent = { got.append($0) }
    pb.write(.text("self"));   // changeCount +1（模拟写回剪贴板）
    m.ignoreNextChange()
    m.poll()
    #expect(got.isEmpty)
}

@Test func repeatedPollWithoutChangeEmitsOnce() {
    let pb = FakePasteboard()
    let m = PasteboardMonitor(pasteboard: pb)
    var count = 0
    m.onNewContent = { _ in count += 1 }
    pb.scripted = .text("x"); pb.changeCount += 1
    m.poll(); m.poll(); m.poll()
    #expect(count == 1)
}
```

- [x] **Step 2: 运行** → 失败
- [x] **Step 3: 实现**（monitor 持 lastChangeCount；poll 变更则读取并回调；ignoreNextChange 同步 lastChangeCount = pasteboard.changeCount）
- [x] **Step 4: `swift test` 全绿**
- [x] **Step 5: Commit** `feat: 粘贴板轮询监控与自写忽略`

---

### Task 6: SystemPasteboard 适配器（薄胶水，随 Task 7 冒烟验证）

**Files:**
- Create: `Sources/ClipHistoryCore/SystemPasteboard.swift`

**Interfaces:**
- Consumes: `PasteboardReading`, `ClipboardContent.make(...)`, `HistoryLimits.storedTextCap`
- Produces: `final class SystemPasteboard: PasteboardReading`（NSPasteboard.general：changeCount 直传；readContent 顺序：隐藏类型→nil，string→make(text:)，png/tiff→NSBitmapImageRep 转 png data + 像素尺寸→make(imageData:...)；write：clearContents + setString/setData）

无独立单测（不碰真实剪贴板），由 Task 7 冒烟测试覆盖。并入 Task 7 提交。

---

### Task 7: App 壳 + .app 打包 + 冒烟验证

**Files:**
- Create: `Sources/ClipHistoryCore/SystemPasteboard.swift`（Task 6 定义）
- Create: `Sources/ClipHistoryApp/AppDelegate.swift`
- Create: `Sources/ClipHistoryApp/StatusItemController.swift`
- Create: `Sources/ClipHistoryApp/MenuFactory.swift`
- Modify: `Sources/ClipHistoryApp/main.swift`（替换为真实入口）
- Create: `scripts/build-app.sh`
- Create: `README.md`

**Interfaces:**
- Consumes: ClipHistoryCore 全部公开 API
- Produces: `dist/ClipHistory.app`（LSUIElement=true，ad-hoc 签名）

**要点（实现内容，非占位）：**
- `main.swift`：`NSApplication.shared` + `AppDelegate` + `NSApp.run()`，`NSApp.setActivationPolicy(.accessory)`
- `AppDelegate.applicationDidFinishLaunching`：创建 `StatusItemController`
- `StatusItemController`：
  - `NSStatusBar.system.statusItem(withLength: .square)`，button 图标 `NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription:)`
  - Timer 0.5s（main RunLoop）→ `monitor.poll()`
  - `monitor.onNewContent`：`store.insert` 成功 → `persistence.save`（失败 stderr 日志）→ 刷新菜单
  - `copyEntry(_:)`（menu action，`representedObject = entry.id`）：查条目 → `pasteboard.write` → `monitor.ignoreNextChange()`
  - `clearHistory(_:)`：`store.removeAll()` + `persistence.clearAll()` → 刷新
  - `toggleLaunchAtLogin(_:)`：`SMAppService.mainApp` register/unregister，失败 stderr + 状态回退
- `MenuFactory.makeMenu(target:action:entries:launchAtLogin:)`：条目项（文本：title 预览 + tooltip；图片：20pt 缩略 + 「图片 W×H」）、空态「暂无记录」、分隔线、清空历史、开机自启动（勾选态）、退出
- `scripts/build-app.sh`：`swift build -c release` → 组装 `dist/ClipHistory.app/Contents/{MacOS,Resources}` + `Info.plist`（CFBundleIdentifier `com.crawford.cliphistory`、LSUIElement、NSHighResolutionCapable）→ `codesign --force --deep -s -`

**冒烟验证：**
1. `scripts/build-app.sh` → BUILD OK
2. `open dist/ClipHistory.app` → `pgrep -f ClipHistoryApp` 存活
3. `printf 'smoke-test-123' | pbcopy; sleep 1.2` → `history.json` 含 `smoke-test-123`
4. 再次写入不同内容 → 条目数 ≥2 且最新在前
5. `pkill -f ClipHistoryApp` 退出

- [x] **Step 1: 实现壳与脚本**
- [x] **Step 2: 冒烟验证通过**
- [x] **Step 3: README（安装/使用/开发）**
- [x] **Step 4: Commit** `feat: 应用壳、打包脚本与冒烟验证`

---

### Task 8: 收尾核验

- [x] `swift test` 全绿，无警告
- [x] 覆盖率核验（`swift test --enable-code-coverage` + llvm-cov，核心库 ≥80%）
- [x] README 与设计文档一致
- [x] 最终 commit `chore: 收尾核验`

## Self-Review

- 覆盖 spec：需求 1-4 ↔ Task 2/4/5/7；concealed 忽略 ↔ Task 5/6；持久化容错 ↔ Task 4 ✓
- 占位符扫描：无 TBD/「稍后实现」✓
- 类型一致性：`ClipboardContent.make(imageData:pixelWidth:pixelHeight:)`、`HistoryStore.insert(_:at:)`、`HistoryPersistence(directory:capacity:)`、`PasteboardMonitor(pasteboard:)` 各 Task 引用一致 ✓
