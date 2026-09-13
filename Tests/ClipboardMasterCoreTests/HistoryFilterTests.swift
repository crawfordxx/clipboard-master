import Testing
import Foundation
@testable import ClipboardMasterCore

// MARK: - 搜索过滤

@Test func filterEmptyQueryMatchesEverything() {
    let image = ClipboardContent.make(imageData: Data([1]), pixelWidth: 6, pixelHeight: 4)!
    #expect(HistoryFilter.matches(.text("abc"), query: ""))
    #expect(HistoryFilter.matches(.text("abc"), query: "   "))
    #expect(HistoryFilter.matches(image, query: ""))
}

@Test func filterTextCaseInsensitive() {
    #expect(HistoryFilter.matches(.text("Hello World"), query: "hello"))
    #expect(HistoryFilter.matches(.text("Hello World"), query: "WORLD"))
    #expect(HistoryFilter.matches(.text("Hello World"), query: "o w"))
    #expect(!HistoryFilter.matches(.text("Hello World"), query: "xyz"))
}

@Test func filterTextMatchesFullBodyNotJustPreview() {
    // 长文本后半段也要能搜到（菜单预览被截断，搜索不截断）
    let long = String(repeating: "x", count: 200) + "needle" + String(repeating: "y", count: 200)
    #expect(HistoryFilter.matches(.text(long), query: "needle"))
}

@Test func filterImageMatchesByLabel() {
    let image = ClipboardContent.make(imageData: Data([1]), pixelWidth: 128, pixelHeight: 64)!
    #expect(HistoryFilter.matches(image, query: "图片"))
    #expect(HistoryFilter.matches(image, query: "128"))
    #expect(!HistoryFilter.matches(image, query: "hello"))
}
