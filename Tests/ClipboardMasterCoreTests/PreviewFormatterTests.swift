import Testing
import Foundation
@testable import ClipboardMasterCore

// MARK: - collapsedText

@Test func collapsedTextFoldsWhitespace() {
    #expect(PreviewFormatter.collapsedText("a\n\n b \t c ", limit: 50) == "a b c")
    #expect(PreviewFormatter.collapsedText("  ", limit: 50) == "")
}

@Test func collapsedTextTruncatesWithEllipsis() {
    #expect(PreviewFormatter.collapsedText("abcdef", limit: 3) == "abc…")
    #expect(PreviewFormatter.collapsedText("abc", limit: 3) == "abc")
    #expect(PreviewFormatter.collapsedText("", limit: 3) == "")
}

// MARK: - menuTitle

@Test func menuTitleTextUsesPreviewLimit() {
    let long = String(repeating: "x", count: HistoryLimits.menuPreviewLimit + 10)
    let title = PreviewFormatter.menuTitle(for: .text(long))
    #expect(title.count == HistoryLimits.menuPreviewLimit + 1) // 含省略号
    #expect(title.hasSuffix("…"))
}

@Test func menuTitlePlainText() {
    #expect(PreviewFormatter.menuTitle(for: .text("hi")) == "hi")
}

@Test func menuTitleImage() {
    let c = ClipboardContent.make(imageData: Data([1]), pixelWidth: 128, pixelHeight: 64)!
    #expect(PreviewFormatter.menuTitle(for: c) == "图片 128×64")
}

// MARK: - tooltip

@Test func tooltipContainsPreviewAndDate() {
    let entry = ClipboardEntry(
        id: UUID(),
        capturedAt: Date(timeIntervalSince1970: 0),
        content: .text("hello")
    )
    let tip = PreviewFormatter.tooltip(for: entry)
    #expect(tip.contains("hello"))
    // Short dates may use two-digit years depending on the system locale.
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    #expect(tip.hasPrefix(formatter.string(from: entry.capturedAt) + "\n"))
}

@Test func tooltipTruncatesLongText() {
    let long = String(repeating: "y", count: HistoryLimits.tooltipPreviewLimit + 10)
    let entry = ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text(long))
    #expect(PreviewFormatter.tooltip(for: entry).contains("…"))
}
