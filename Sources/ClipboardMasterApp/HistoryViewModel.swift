import Combine
import Foundation
import ClipboardMasterCore

/// 历史窗口视图模型：持有条目快照与搜索词，动作用回调交还控制器执行。
/// 与 StatusItemController 同样只在主线程使用。
final class HistoryViewModel: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published var query = ""

    var onPreview: ((UUID) -> Void)?
    var onCopy: ((UUID) -> Void)?
    var onDelete: ((UUID) -> Void)?
    var onReveal: ((UUID) -> Void)?
    var onClearAll: (() -> Void)?

    var filtered: [ClipboardEntry] {
        entries.filter { HistoryFilter.matches($0.content, query: query) }
    }

    var countText: String {
        let shown = filtered.count
        return query.isEmpty ? "\(entries.count) 条记录" : "\(shown) / \(entries.count) 条"
    }

    func update(_ newEntries: [ClipboardEntry]) {
        entries = newEntries
    }

    func preview(_ id: UUID) { onPreview?(id) }
    func copy(_ id: UUID) { onCopy?(id) }
    func delete(_ id: UUID) { onDelete?(id) }
    func reveal(_ id: UUID) { onReveal?(id) }
    func clearAll() { onClearAll?() }
}
