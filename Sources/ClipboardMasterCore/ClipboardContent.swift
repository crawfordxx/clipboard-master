import Foundation

/// 剪贴板内容：文本或图片。
/// 值语义，相等性：文本按字符；图片按数据字节（尺寸不参与比较）。
public enum ClipboardContent: Equatable {
    case text(String)
    case image(imageData: Data, pixelWidth: Int, pixelHeight: Int)

    /// 相等性：文本按字符；图片仅按数据字节（尺寸不参与比较）。
public static func == (lhs: ClipboardContent, rhs: ClipboardContent) -> Bool {
        switch (lhs, rhs) {
        case let (.text(a), .text(b)):
            return a == b
        case let (.image(imageData: a, _, _), .image(imageData: b, _, _)):
            return a == b
        default:
            return false
        }
    }

    /// 边界校验工厂：文本 trim 后为空返回 nil，超长截断到 `HistoryLimits.storedTextCap`。
public static func make(text: String) -> ClipboardContent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count > HistoryLimits.storedTextCap {
            let start = trimmed.startIndex
            let end = trimmed.index(start, offsetBy: HistoryLimits.storedTextCap)
            return .text(String(trimmed[start..<end]))
        }
        return .text(trimmed)
    }

    /// 边界校验工厂：图片数据非空、宽高为正才接受。
public static func make(imageData: Data, pixelWidth: Int, pixelHeight: Int) -> ClipboardContent? {
        guard !imageData.isEmpty, pixelWidth > 0, pixelHeight > 0 else { return nil }
        return .image(imageData: imageData, pixelWidth: pixelWidth, pixelHeight: pixelHeight)
    }
}
