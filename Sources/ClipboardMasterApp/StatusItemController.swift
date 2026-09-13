import AppKit
import ClipboardMasterCore
import ServiceManagement

/// 菜单栏控制器：状态栏图标、轮询定时器、历史存储与持久化的编排。
/// 所有操作在主线程。
final class StatusItemController: NSObject {
    private let pasteboard: SystemPasteboard
    private let monitor: PasteboardMonitor
    private var store: HistoryStore
    private let persistence: HistoryPersistence
    private let statusItem: NSStatusItem
    private var timer: Timer?

    override init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = appSupport.appendingPathComponent("ClipboardMaster", isDirectory: true)
        // v1 目录名迁移：ClipHistory → ClipboardMaster（仅在新目录不存在时执行一次）
        let legacyDirectory = appSupport.appendingPathComponent("ClipHistory", isDirectory: true)
        HistoryPersistence.migrateLegacyDirectory(from: legacyDirectory, to: directory)

        let systemPasteboard = SystemPasteboard()
        self.pasteboard = systemPasteboard
        self.monitor = PasteboardMonitor(pasteboard: systemPasteboard)
        self.persistence = HistoryPersistence(directory: directory)
        self.store = HistoryStore(entries: persistence.load())
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "剪贴板历史")
        }
        refreshMenu()

        monitor.onNewContent = { [weak self] content in
            guard let self else { return }
            self.store.insert(content)
            self.saveAndRefresh()
        }
        timer = Timer.scheduledTimer(
            withTimeInterval: HistoryLimits.pollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.monitor.poll()
        }
    }

    // MARK: - 菜单动作

    /// 点击历史条目：复制回剪贴板（并吞掉自我变更，避免回环记录）。
    @objc private func copyEntry(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let entry = store.entry(id: id)
        else { return }
        pasteboard.write(entry.content)
        monitor.ignoreNextChange()
    }

    @objc private func clearHistory() {
        store.removeAll()
        do {
            try persistence.clearAll()
        } catch {
            logError("清空历史失败", error)
        }
        refreshMenu()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            logError("切换开机自启动失败（需从 .app 运行）", error)
        }
        sender.state = service.status == .enabled ? .on : .off
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - 私有

    private func saveAndRefresh() {
        do {
            try persistence.save(store.entries)
        } catch {
            logError("保存历史失败（内存历史不受影响）", error)
        }
        refreshMenu()
    }

    private func refreshMenu() {
        statusItem.menu = MenuFactory.makeMenu(
            target: self,
            copyAction: #selector(copyEntry(_:)),
            clearAction: #selector(clearHistory),
            launchAtLoginAction: #selector(toggleLaunchAtLogin(_:)),
            quitAction: #selector(quit),
            entries: store.entries,
            launchAtLogin: SMAppService.mainApp.status == .enabled
        )
    }

    private func logError(_ context: String, _ error: Error) {
        FileHandle.standardError.write(Data("[ClipboardMaster] \(context): \(error)\n".utf8))
    }
}
