import AppKit
import Testing
@testable import ClipboardMasterCore

@Test func namedPasteboardReportsSuccessfulTextWrite() {
    let board = NSPasteboard(name: .init("ClipboardMasterTests.\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
    let writer = SystemPasteboard(pasteboard: board)
    #expect(writer.writeReportingSuccess(.text("copy-button-fixture")))
    #expect(board.string(forType: .string) == "copy-button-fixture")
}

@Test func namedPasteboardCopiesImageAndReplacesOldText() throws {
    let board = NSPasteboard(name: .init("ClipboardMasterTests.\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
    let writer = SystemPasteboard(pasteboard: board)
    let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 4, bitsPerPixel: 32))
    bitmap.setColor(NSColor(deviceRed: 0.2, green: 0.4, blue: 0.9, alpha: 1), atX: 0, y: 0)
    let png = try #require(bitmap.representation(using: .png, properties: [:]))
    #expect(writer.writeReportingSuccess(.text("previous-fixture")))
    #expect(writer.writeReportingSuccess(.image(imageData: png, pixelWidth: 1, pixelHeight: 1)))
    #expect(board.data(forType: .png) == png)
    #expect(board.string(forType: .string) == nil)
}
