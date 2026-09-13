import Foundation

/// 一条历史记录：内容 + 捕获时间 + 稳定 id（供菜单点击回查）。
public struct ClipboardEntry: Identifiable, Equatable {
    public let id: UUID
    public let capturedAt: Date
    public let content: ClipboardContent
}
