import Foundation

/// 粘贴板轮询监控：对比 changeCount 检测变更。
/// `ignoreNextChange()` 用于用户点击历史条目写回剪贴板后吞掉自我变更，避免回环记录。
public final class PasteboardMonitor {
    private let pasteboard: PasteboardReading
    private var lastChangeCount: Int

    /// 检测到新内容时回调（主线程调用）。
    public var onNewContent: ((ClipboardContent) -> Void)?

    public init(pasteboard: PasteboardReading) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    public func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        guard let content = pasteboard.readContent() else { return }
        onNewContent?(content)
    }

    /// 将已发生的写回标记为已消费（同步 lastChangeCount）。
    public func ignoreNextChange() {
        lastChangeCount = pasteboard.changeCount
    }
}
