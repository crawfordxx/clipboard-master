import AppKit
import SwiftUI
import ClipboardMasterCore

/// 历史窗口控制器：懒创建 NSWindow，宿主 SwiftUI 视图。
final class HistoryWindowController {
    private let viewModel = HistoryViewModel()
    private var window: NSWindow?

    /// 供控制器挂接 copy/delete/reveal/clear 回调。
    var hooks: HistoryViewModel { viewModel }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: HistoryView(vm: viewModel))
            let newWindow = NSWindow(contentViewController: host)
            newWindow.title = "Clipboard Master · 历史记录"
            newWindow.styleMask.insert(.miniaturizable)
            newWindow.setFrameAutosaveName("ClipboardMasterHistoryWindow")
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            window = newWindow
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 历史变化时同步窗口内容（窗口未打开也安全，仅更新数据）。
    func refresh(_ entries: [ClipboardEntry]) {
        viewModel.update(entries)
    }
}
