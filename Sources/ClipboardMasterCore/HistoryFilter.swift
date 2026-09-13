import Foundation

/// 历史搜索过滤（大小写不敏感；文本搜全文，图片按标签）。
public enum HistoryFilter {
    public static func matches(_ content: ClipboardContent, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        switch content {
        case .text(let text):
            return text.range(of: trimmed, options: .caseInsensitive) != nil
        case .image:
            return PreviewFormatter.menuTitle(for: content)
                .range(of: trimmed, options: .caseInsensitive) != nil
        }
    }
}
