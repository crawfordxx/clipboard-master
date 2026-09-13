import AppKit
import ClipboardMasterCore
import ServiceManagement
import SwiftUI

/// 菜单栏控制器：状态栏图标、轮询定时器、历史存储与持久化、历史窗口的编排。
/// 所有操作在主线程。
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let pasteboard: SystemPasteboard
    private let monitor: PasteboardMonitor
    private var store: HistoryStore
    private let persistence: HistoryPersistence
    private let statusItem: NSStatusItem
    private var timer: Timer?
    private let historyWindow = HistoryWindowController()
    private var editors: [UUID: EntryEditorWindowController] = [:]
    private var updateChecker: UpdateChecker!
    private let popover = NSPopover()
    private let panelModel = MenuPanelModel()
    private var previousApplication: NSRunningApplication?

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
        updateChecker.beforeInstall = { [weak self] in
            guard let self else { return false }
            self.previousApplication = nil
            self.popover.performClose(nil)
            guard self.confirmPendingEdits() else { return false }
            // The updater restarts the process; close confirmed drafts before it can run.
            for editor in Array(self.editors.values) { editor.closeAfterConfirmation() }
            return true
        }
        updateChecker.onStateChange = { [weak self] in self?.refreshMenu() }
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MenuPanelView(
            model: panelModel, updater: updateChecker,
            onCopy: { [weak self] id in
                if self?.copyEntryById(id) == true { self?.popover.performClose(nil) }
            },
            onReveal: { [weak self] id in self?.popover.performClose(nil); self?.revealEntryById(id) },
            onOpenHistory: { [weak self] in
                self?.previousApplication = nil
                self?.popover.performClose(nil)
                self?.openHistoryWindow()
            },
            onClear: { [weak self] in self?.clearHistory() },
            onToggleLogin: { [weak self] in self?.toggleLaunchAtLogin() },
            onClose: { [weak self] in self?.popover.performClose(nil) },
            onQuit: { [weak self] in self?.quit() },
            onCopyInPlace: { [weak self] id in self?.copyEntryById(id) },
            onPreview: { [weak self] id in self?.openEntryById(id) }
        ))
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
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
            guard let self else { return }
            self.panelModel.synchronizeClipboard(changeCount: self.pasteboard.changeCount)
            self.monitor.poll()
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

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            previousApplication = NSWorkspace.shared.frontmostApplication
            panelModel.synchronizeClipboard(changeCount: pasteboard.changeCount)
            refreshMenu()
            Self.preparePopoverForDisplay(popover)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    /// Position using the SwiftUI content size, not NSPopover's 320×320 fallback.
    static func preparePopoverForDisplay(_ popover: NSPopover) {
        guard let view = popover.contentViewController?.view else { return }
        view.layoutSubtreeIfNeeded()
        popover.contentSize = view.fittingSize
    }

    func popoverDidClose(_ notification: Notification) {
        defer { previousApplication = nil }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier,
              let previousApplication, !previousApplication.isTerminated else { return }
        previousApplication.activate(options: [])
    }

    @discardableResult
    private func copyEntryById(_ id: UUID) -> Bool {
        guard let entry = store.entry(id: id) else { return false }
        let copied = pasteboard.writeReportingSuccess(entry.content)
        monitor.ignoreNextChange()
        guard copied else {
            panelModel.clearCopyFeedback()
            panelModel.notice = "复制失败，请重试。"
            return false
        }
        panelModel.recordCopy(id, changeCount: pasteboard.changeCount)
        return true
    }

    private func openEntryById(_ id: UUID) {
        if case .installing = updateChecker.state {
            panelModel.notice = "更新安装中，完成后再打开编辑器。"
            return
        }
        guard let entry = store.entry(id: id) else { return }
        previousApplication = nil
        popover.performClose(nil)
        if let editor = editors[id] { editor.show(); return }
        let model = EntryEditorModel(entry: entry, imageURL: persistence.imageFileURL(for: entry), onSave: { [weak self] id, expected, text in
            guard let self else { throw EntryEditError.missingEntry }
            var updated = self.store
            try updated.replaceText(id: id, expected: expected, with: text)
            // Commit durable state before publishing the edited record or success feedback.
            try self.persistence.save(updated.entries)
            self.store = updated
            if self.panelModel.copiedEntryID == id { self.panelModel.clearCopyFeedback() }
            self.refreshMenu()
        }, onCopy: { [weak self] id in self?.copyEntryById(id) ?? false })
        let editor = EntryEditorWindowController(model: model)
        editor.onClose = { [weak self] in self?.editors.removeValue(forKey: id) }
        editors[id] = editor
        editor.show()
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

    private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            panelModel.notice = "无法切换开机自启动，请从已安装的应用运行，并检查系统设置中的登录项。"
            logError("切换开机自启动失败（需从 .app 运行）", error)
        }
        panelModel.launchAtLogin = service.status == .enabled
    }

    func confirmPendingEdits() -> Bool {
        Array(editors.values).allSatisfy { $0.confirmDiscardOrSave() }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - 私有

    private func wireHistoryWindow() {
        let hooks = historyWindow.hooks
        hooks.onPreview = { [weak self] id in self?.openEntryById(id) }
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
        for (id, editor) in editors where store.entry(id: id) == nil { editor.model.markUnavailable() }
        panelModel.entries = store.entries
        panelModel.launchAtLogin = SMAppService.mainApp.status == .enabled
        historyWindow.refresh(store.entries)
    }

    private func logError(_ context: String, _ error: Error) {
        FileHandle.standardError.write(Data("[ClipboardMaster] \(context): \(error)\n".utf8))
    }
}
