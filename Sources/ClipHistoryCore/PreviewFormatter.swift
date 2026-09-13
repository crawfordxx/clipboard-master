import Foundation

/// 菜单展示用的文本格式化（纯函数，无副作用）。
enum PreviewFormatter {
    /// 折叠所有空白为单个空格；超长保留 limit 个字符后加省略号。
    static func collapsedText(_ text: String, limit: Int) -> String {
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard collapsed.count > limit, limit > 0 else { return collapsed }
        let start = collapsed.startIndex
        let end = collapsed.index(start, offsetBy: limit)
        return String(collapsed[start..<end]) + "…"
    }

    /// 菜单条目标题：文本走折叠预览；图片显示「图片 W×H」。
    static func menuTitle(for content: ClipboardContent) -> String {
        switch content {
        case .text(let text):
            return collapsedText(text, limit: HistoryLimits.menuPreviewLimit)
        case let .image(_, w, h):
            return "图片 \(w)×\(h)"
        }
    }

    /// 悬浮提示：本地化时间 + 更长的内容预览。
    static func tooltip(for entry: ClipboardEntry) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        let time = formatter.string(from: entry.capturedAt)
        switch entry.content {
        case .text(let text):
            return time + "\n" + collapsedText(text, limit: HistoryLimits.tooltipPreviewLimit)
        case .image:
            return time + "\n" + menuTitle(for: entry.content)
        }
    }
}
