import Foundation

/// 粘贴板抽象：生产环境由 `SystemPasteboard`（NSPasteboard.general）实现，
/// 测试用 Fake 实现，避免触碰真实系统状态。
protocol PasteboardReading: AnyObject {
    /// 系统粘贴板变更计数（任何写操作都会使其递增）。
    var changeCount: Int { get }
    /// 读取当前内容；不可读/空/隐藏（密码管理器标记）返回 nil。
    func readContent() -> ClipboardContent?
    /// 写入内容（用于历史条目复制回剪贴板）。
    func write(_ content: ClipboardContent)
}
