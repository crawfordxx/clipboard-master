import AppKit

/// `PasteboardReading` 的系统实现（NSPasteboard.general）。
/// 薄胶水层：核心逻辑已被单元测试覆盖，本类由冒烟测试验证。
public final class SystemPasteboard: PasteboardReading {
    /// 密码管理器等标记的隐藏类型，不应被记录。
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public var changeCount: Int { pasteboard.changeCount }

    public func readContent() -> ClipboardContent? {
        let types = pasteboard.types ?? []
        guard !types.contains(Self.concealedType) else { return nil }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty, urls.allSatisfy(EntryReferences.isSupported) {
            return ClipboardContent.make(text: urls.map(\.absoluteString).joined(separator: "\n"))
        }
        if let text = pasteboard.string(forType: .string) {
            return ClipboardContent.make(text: text)
        }
        return readImage()
    }

    public func write(_ content: ClipboardContent) {
        _ = writeReportingSuccess(content)
    }

    /// Acknowledges the actual pasteboard write before showing success feedback.
    @discardableResult
    public func writeReportingSuccess(_ content: ClipboardContent) -> Bool {
        pasteboard.clearContents()
        switch content {
        case .text(let text):
            let files = EntryReferences.fileURLs(in: text)
            if !files.isEmpty {
                let items = files.map { url in
                    let item = NSPasteboardItem()
                    item.setString(url.absoluteString, forType: .fileURL)
                    item.setString(url.absoluteString, forType: .string)
                    return item
                }
                return pasteboard.writeObjects(items)
            }
            return pasteboard.setString(text, forType: .string)
        case .image(let imageData, _, _):
            return pasteboard.setData(imageData, forType: .png)
        }
    }

    /// 统一读取为 PNG：png/tiff 均经 NSBitmapImageRep 归一化，并取像素尺寸。
    private func readImage() -> ClipboardContent? {
        let rawData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff)
        guard let rawData, let rep = NSBitmapImageRep(data: rawData) else { return nil }
        guard let pngData = rep.representation(using: .png, properties: [:]) else { return nil }
        return ClipboardContent.make(
            imageData: pngData,
            pixelWidth: rep.pixelsWide,
            pixelHeight: rep.pixelsHigh
        )
    }
}
