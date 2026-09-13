import AppKit
import ClipboardMasterCore
import ServiceManagement

/// 菜单栏控制器：状态栏图标、轮询定时器、历史存储与持久化、历史窗口的编排。
/// 所有操作在主线程。
final class StatusItemController: NSObject {
    private let pasteboard: SystemPasteboard
    private let monitor: PasteboardMonitor
    private var store: HistoryStore
    private let persistence: HistoryPersistence
    private let statusItem: NSStatusItem
    private var timer: Timer?
    private let historyWindow = HistoryWindowController()
    private var updateChecker: UpdateChecker!

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
        updateChecker = UpdateChecker(dataDirectory: directory)
        updateChecker.onStateChange = { [weak self] in self?.refreshMenu() }
        wireHistoryWindow()
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

        // 支持启动参数 --open-window 直接打开历史窗口（供冒烟测试/Agent 验证）
        if CommandLine.arguments.contains("--open-window") {
            DispatchQueue.main.async { [weak self] in
                self?.openHistoryWindow()
            }
        }

        // 启动后静默检查更新（间隔 24h）
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.updateChecker.checkAutomaticallyIfNeeded()
        }
    }

    // MARK: - 菜单动作

    /// 点击历史条目：复制回剪贴板（并吞掉自我变更，避免回环记录）。
    @objc private func copyEntry(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        copyEntryById(id)
    }

    private func copyEntryById(_ id: UUID) {
        guard let entry = store.entry(id: id) else { return }
        pasteboard.write(entry.content)
        monitor.ignoreNextChange()
    }

    /// 在 Finder 中定位图片条目的落盘文件。
    @objc private func revealEntry(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        revealEntryById(id)
    }

    private func revealEntryById(_ id: UUID) {
        guard let entry = store.entry(id: id),
              let url = persistence.imageFileURL(for: entry)
        else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func deleteEntryById(_ id: UUID) {
        store.remove(id: id)
        saveAndRefresh()
    }

    @objc private func openHistoryWindow() {
        historyWindow.show()
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

    // MARK: - 更新

    @objc private func checkForUpdates() {
        updateChecker.checkNow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.reportUpdateResult()
        }
    }

    private func reportUpdateResult() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        switch updateChecker.state {
        case .available(let latest):
            alert.messageText = "发现新版本 v\(latest)"
            alert.informativeText = "当前 v\(updateChecker.currentVersion)。更新将自动完成并重启应用，历史数据不受影响。"
            alert.addButton(withTitle: "立即更新")
            alert.addButton(withTitle: "稍后")
            if alert.runModal() == .alertFirstButtonReturn {
                updateChecker.startUpdate()
            }
        case .upToDate:
            alert.messageText = "已是最新版本"
            alert.informativeText = "当前 v\(updateChecker.currentVersion)"
            alert.runModal()
        default:
            alert.messageText = "检查更新失败"
            alert.informativeText = "网络不可用或 GitHub 无法访问，请稍后再试。"
            alert.runModal()
        }
    }

    @objc private func startUpdate() {
        updateChecker.startUpdate()
    }

    // MARK: - 私有

    private func wireHistoryWindow() {
        let hooks = historyWindow.hooks
        hooks.onCopy = { [weak self] id in self?.copyEntryById(id) }
        hooks.onDelete = { [weak self] id in self?.deleteEntryById(id) }
        hooks.onReveal = { [weak self] id in self?.revealEntryById(id) }
        hooks.onClearAll = { [weak self] in self?.clearHistory() }
        historyWindow.refresh(store.entries)
    }

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
            openWindowAction: #selector(openHistoryWindow),
            checkUpdateAction: #selector(checkForUpdates),
            startUpdateAction: #selector(startUpdate),
            availableVersion: updateChecker?.availableVersion,
            entries: store.entries,
            launchAtLogin: SMAppService.mainApp.status == .enabled,
            copyHandler: { [weak self] id in self?.copyEntryById(id) },
            revealHandler: { [weak self] id in self?.revealEntryById(id) }
        )
        historyWindow.refresh(store.entries)
    }

    private func logError(_ context: String, _ error: Error) {
        FileHandle.standardError.write(Data("[ClipboardMaster] \(context): \(error)\n".utf8))
    }
}
