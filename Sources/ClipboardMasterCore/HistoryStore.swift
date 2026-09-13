import Foundation

/// 内存历史存储（值语义 struct，无共享可变状态）。
/// 职责：最新在前插入、内容去重（重复内容不重建条目）、容量淘汰最旧、按 id 查询。
public struct HistoryStore {
    public private(set) var entries: [ClipboardEntry] = []
    public let capacity: Int

    /// - Parameter entries: 预加载的历史（最新在前，如 `HistoryPersistence.load()` 输出）。
    public init(entries: [ClipboardEntry] = [], capacity: Int = HistoryLimits.capacity) {
        self.entries = Array(entries.prefix(max(1, capacity)))
        self.capacity = max(1, capacity)
    }

    /// 插入新内容。
    /// - Returns: true 表示新增；false 表示内容与现存条目重复（保留原条目与时间戳，但移到最前，去重保新鲜）。
    @discardableResult
    public mutating func insert(_ content: ClipboardContent, at date: Date = Date()) -> Bool {
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

    /// Replace in place; reject stale edits instead of resurrecting or overwriting records.
    public mutating func replaceText(id: UUID, expected: String, with text: String) throws {
        guard let entry = entry(id: id) else { throw EntryEditError.missingEntry }
        guard case .text(let current) = entry.content else { throw EntryEditError.notText }
        guard current == expected else { throw EntryEditError.conflict }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw EntryEditError.emptyText }
        guard text.count <= HistoryLimits.storedTextCap else { throw EntryEditError.tooLong }
        entries = entries.filter { $0.id == id || $0.content != .text(text) }.map {
            $0.id == id ? ClipboardEntry(id: id, capturedAt: entry.capturedAt, content: .text(text)) : $0
        }
    }

    public mutating func removeAll() {
        entries.removeAll()
    }

    public func entry(id: UUID) -> ClipboardEntry? {
        entries.first { $0.id == id }
    }

    /// 删除单条；条目不存在返回 false（幂等）。
    @discardableResult
    public mutating func remove(id: UUID) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }
        entries.remove(at: index)
        return true
    }
}
