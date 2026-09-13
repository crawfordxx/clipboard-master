import Foundation

/// Display/open targets only. Never evaluates clipboard text or custom URL schemes.
public enum EntryReferences {
    public static func urls(in text: String) -> [URL] {
        var result: [URL] = []
        func append(_ url: URL) {
            guard isSupported(url) else { return }
            let target = url.isFileURL ? url.standardizedFileURL : url
            if !result.contains(target) { result.append(target) }
        }
        for line in text.components(separatedBy: .newlines) {
            let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.hasPrefix("/") || value.hasPrefix("~/") {
                append(URL(fileURLWithPath: (value as NSString).expandingTildeInPath))
            } else if value.lowercased().hasPrefix("file:"), let url = URL(string: value) {
                append(url)
            }
        }
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let url = match.url { append(url) }
            }
        }
        return result
    }

    public static func isSupported(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "http", "https": return !(url.host ?? "").isEmpty
        case "file": return (url.host ?? "").isEmpty || url.host == "localhost"
        default: return false
        }
    }

    /// Only a complete list of file:// URLs is copied as Finder file references.
    public static func fileURLs(in text: String) -> [URL] {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let urls = lines.compactMap { value -> URL? in
            guard value.lowercased().hasPrefix("file:"), let url = URL(string: value),
                  url.isFileURL, isSupported(url) else { return nil }
            return url.standardizedFileURL
        }
        return !lines.isEmpty && urls.count == lines.count ? urls : []
    }
}

public enum EntryEditError: Error, LocalizedError, Equatable {
    case missingEntry, conflict, notText, emptyText, tooLong

    public var errorDescription: String? {
        switch self {
        case .missingEntry: return "这条记录已被删除或淘汰，无法保存。草稿仍在，可选中文字手动复制。"
        case .conflict: return "这条记录已在其他窗口修改。草稿已保留，请重新打开最新记录。"
        case .notText: return "图片记录不能作为文字修改。"
        case .emptyText: return "内容不能为空。"
        case .tooLong: return "内容超过 \(HistoryLimits.storedTextCap) 字，请缩短后再保存。"
        }
    }
}
