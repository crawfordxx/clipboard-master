import AppKit
import SwiftUI

final class EntryEditorWindowController: NSObject, NSWindowDelegate {
    let model: EntryEditorModel
    private var window: NSWindow?
    var onClose: (() -> Void)?

    init(model: EntryEditorModel) { self.model = model }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: EntryEditorView(model: model))
            let window = NSWindow(contentViewController: host)
            window.title = "Clipboard Master · 预览与编辑"
            window.styleMask.formUnion([.resizable, .miniaturizable])
            window.setContentSize(NSSize(width: 680, height: 640))
            window.minSize = NSSize(width: 520, height: 460)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { confirmDiscardOrSave() }

    func closeAfterConfirmation() { window?.close() }

    func confirmDiscardOrSave() -> Bool {
        guard model.isDirty else { return true }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "要保存「\(String(model.originalText.prefix(32)).replacingOccurrences(of: "\n", with: " "))」的修改吗？"
        alert.informativeText = "未保存的草稿会丢失，原历史记录不受影响。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "不保存")
        alert.addButton(withTitle: "取消")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return model.save()
        case .alertSecondButtonReturn: return true
        default: return false
        }
    }

    func windowWillClose(_ notification: Notification) { onClose?() }
}
