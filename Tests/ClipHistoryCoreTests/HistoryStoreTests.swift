import Testing
import Foundation
@testable import ClipHistoryCore

// MARK: - 预加载

@Test func seedingWithLoadedEntriesKeepsOrder() {
    let entries = (0..<5).map {
        ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("e\($0)"))
    }
    let store = HistoryStore(entries: Array(entries.dropFirst()), capacity: 10)
    #expect(store.entries.map(\.content) == [.text("e4"), .text("e3"), .text("e2"), .text("e1")])
}

@Test func seedingTrimsToCapacity() {
    let entries = (0..<5).map {
        ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("e\($0)"))
    }
    let store = HistoryStore(entries: entries, capacity: 2)
    #expect(store.entries.map(\.content) == [.text("e4"), .text("e3")])
}

// MARK: - 插入与排序

@Test func insertPutsNewestFirst() {
    var store = HistoryStore()
    let first = store.insert(.text("a"))
    let second = store.insert(.text("b"))
    #expect(first && second)
    #expect(store.entries.map(\.content) == [.text("b"), .text("a")])
}

// MARK: - 去重

@Test func insertDuplicateRemovesOldAndMovesToTop() {
    var store = HistoryStore()
    store.insert(.text("a"))
    store.insert(.text("b"))
    store.insert(.text("a"))
    #expect(store.entries.map(\.content) == [.text("a"), .text("b")])
}

@Test func duplicateInsertReturnsFalseAndKeepsOriginalTimestamp() {
    var store = HistoryStore()
    let t0 = Date(timeIntervalSince1970: 100)
    let t1 = Date(timeIntervalSince1970: 200)
    let first = store.insert(.text("a"), at: t0)
    #expect(first)
    #expect(store.insert(.text("a"), at: t1) == false)
    #expect(store.entries.count == 1)
    #expect(store.entries[0].capturedAt == t0)
}

@Test func duplicateImageContentDedupes() {
    var store = HistoryStore()
    let img = ClipboardContent.make(imageData: Data([1, 2]), pixelWidth: 4, pixelHeight: 4)!
    let added = store.insert(img)
    #expect(added)
    store.insert(.text("t"))
    #expect(store.insert(img) == false)
    #expect(store.entries.map(\.content) == [img, .text("t")])
}

// MARK: - 容量淘汰

@Test func capacityTrimsOldest() {
    var store = HistoryStore(capacity: 3)
    for i in 0..<5 { store.insert(.text("t\(i)")) }
    #expect(store.entries.count == 3)
    #expect(store.entries.map(\.content) == [.text("t4"), .text("t3"), .text("t2")])
}

@Test func duplicateBeyondCapacityStillDedupes() {
    var store = HistoryStore(capacity: 2)
    store.insert(.text("a"))
    store.insert(.text("b"))
    store.insert(.text("a"))
    #expect(store.entries.map(\.content) == [.text("a"), .text("b")])
}

// MARK: - 清空与查询

@Test func entryById() {
    var store = HistoryStore()
    store.insert(.text("x"))
    let id = store.entries[0].id
    #expect(store.entry(id: id)?.content == .text("x"))
    #expect(store.entry(id: UUID()) == nil)
}

@Test func removeAll() {
    var store = HistoryStore()
    store.insert(.text("x"))
    store.removeAll()
    #expect(store.entries.isEmpty)
    #expect(store.entry(id: store.entries.first?.id ?? UUID()) == nil)
}
