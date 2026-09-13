import Foundation

/// 内存历史存储（值语义 struct，无共享可变状态）。
/// 职责：最新在前插入、内容去重（重复内容不重建条目）、容量淘汰最旧、按 id 查询。
struct HistoryStore {
    private(set) var entries: [ClipboardEntry] = []
    let capacity: Int

    init(capacity: Int = HistoryLimits.capacity) {
        self.capacity = max(1, capacity)
    }

    /// 插入新内容。
    /// - Returns: true 表示新增；false 表示内容与现存条目重复（保留原条目与时间戳，但移到最前，去重保新鲜）。
    @discardableResult
    mutating func insert(_ content: ClipboardContent, at date: Date = Date()) -> Bool {
        if let existingIndex = entries.firstIndex(where: { $0.content == content }) {
            let existing = entries.remove(at: existingIndex)
            entries.insert(existing, at: 0)
            return false
        }
        entries.insert(ClipboardEntry(id: UUID(), capturedAt: date, content: content), at: 0)
        if entries.count > capacity {
            entries = Array(entries.prefix(capacity))
        }
        return true
    }

    mutating func removeAll() {
        entries.removeAll()
    }

    func entry(id: UUID) -> ClipboardEntry? {
        entries.first { $0.id == id }
    }
}
