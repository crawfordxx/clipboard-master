import Foundation

/// 一条历史记录：内容 + 捕获时间 + 稳定 id（供菜单点击回查）。
struct ClipboardEntry: Identifiable, Equatable {
    let id: UUID
    let capturedAt: Date
    let content: ClipboardContent
}
