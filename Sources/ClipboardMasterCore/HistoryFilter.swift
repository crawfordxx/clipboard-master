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

/// 相对时间描述：刚刚 / N 分钟前 / N 小时前 / N 天前；超过 7 天回退为日期。
public enum RelativeTimeFormatter {
    private static let minute: TimeInterval = 60
    private static let hour: TimeInterval = 3600
    private static let day: TimeInterval = 86_400
    private static let fallbackDays = 7

    public static func string(from date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 10 { return "刚刚" }
        if seconds < hour {
            let minutes = Int(seconds / minute)
            return minutes <= 1 ? "1 分钟前" : "\(minutes) 分钟前"
        }
        if seconds < day {
            let hours = Int(seconds / hour)
            return hours <= 1 ? "1 小时前" : "\(hours) 小时前"
        }
        if seconds < Double(fallbackDays) * day {
            let days = Int(seconds / day)
            return days <= 1 ? "1 天前" : "\(days) 天前"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
