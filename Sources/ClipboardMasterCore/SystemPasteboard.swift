import AppKit

/// `PasteboardReading` 的系统实现（NSPasteboard.general）。
/// 薄胶水层：核心逻辑已被单元测试覆盖，本类由冒烟测试验证。
public final class SystemPasteboard: PasteboardReading {
    /// 密码管理器等标记的隐藏类型，不应被记录。
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    private let pasteboard = NSPasteboard.general

    public init() {}

    public var changeCount: Int { pasteboard.changeCount }

    public func readContent() -> ClipboardContent? {
        let types = pasteboard.types ?? []
        guard !types.contains(Self.concealedType) else { return nil }
        if let text = pasteboard.string(forType: .string) {
            return ClipboardContent.make(text: text)
        }
        return readImage()
    }

    public func write(_ content: ClipboardContent) {
        pasteboard.clearContents()
        switch content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let imageData, _, _):
            pasteboard.setData(imageData, forType: .png)
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
