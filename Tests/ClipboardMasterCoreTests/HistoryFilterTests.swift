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

// MARK: - 相对时间

@Test func relativeTimeJustNow() {
    let now = Date(timeIntervalSince1970: 1000)
    #expect(RelativeTimeFormatter.string(from: now - 5, now: now) == "刚刚")
}

@Test func relativeTimeMinutesAndHoursAndDays() {
    let now = Date(timeIntervalSince1970: 100_000)
    #expect(RelativeTimeFormatter.string(from: now - 90, now: now) == "1 分钟前")
    #expect(RelativeTimeFormatter.string(from: now - 7200, now: now) == "2 小时前")
    #expect(RelativeTimeFormatter.string(from: now - 3 * 86_400, now: now) == "3 天前")
}

@Test func relativeTimeFutureClampsToJustNow() {
    let now = Date(timeIntervalSince1970: 100_000)
    #expect(RelativeTimeFormatter.string(from: now + 60, now: now) == "刚刚") // 时钟微小偏移友好处理
}

@Test func relativeTimeFarPastFallsBackToDate() {
    let now = Date(timeIntervalSince1970: 100_000_000)
    #expect(RelativeTimeFormatter.string(from: now - 30 * 86_400, now: now).contains("1973"))
}
