import Testing
import Foundation
import AppKit
@testable import ClipboardMasterCore

@Test func editKeepsIdentityTimeAndWhitespaceAndPersists() throws {
    var store = HistoryStore(); store.insert(.text("old"), at: Date(timeIntervalSince1970: 100))
    let old = store.entries[0]
    try store.replaceText(id: old.id, expected: "old", with: "  edited\n  ")
    #expect(store.entries[0].id == old.id)
    #expect(store.entries[0].capturedAt == old.capturedAt)
    #expect(store.entries[0].content == .text("  edited\n  "))
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let persistence = HistoryPersistence(directory: dir)
    try persistence.save(store.entries)
    #expect(persistence.load() == store.entries)
}

@Test func invalidOrStaleEditDoesNotMutateHistory() throws {
    var store = HistoryStore(); store.insert(.text("old")); let id = store.entries[0].id
    let before = store.entries
    #expect(throws: EntryEditError.emptyText) { try store.replaceText(id: id, expected: "old", with: " \n ") }
    #expect(throws: EntryEditError.tooLong) { try store.replaceText(id: id, expected: "old", with: String(repeating: "a", count: HistoryLimits.storedTextCap + 1)) }
    #expect(throws: EntryEditError.conflict) { try store.replaceText(id: id, expected: "stale", with: "new") }
    #expect(throws: EntryEditError.missingEntry) { try store.replaceText(id: UUID(), expected: "old", with: "new") }
    #expect(store.entries == before)
}

@Test func editDeduplicatesWithoutLosingEditedIdentity() throws {
    var store = HistoryStore(); store.insert(.text("a")); let id = store.entries[0].id; store.insert(.text("b"))
    try store.replaceText(id: id, expected: "a", with: "b")
    #expect(store.entries.count == 1 && store.entries[0].id == id)
}

@Test func referencesAllowWebAndLocalFilesButNotExecutableSchemes() {
    let refs = EntryReferences.urls(in: "网页 https://example.com/a\nfile:///tmp/a%20b.pdf\n/tmp/file.txt\njavascript:alert(1)\nssh://host/test")
    #expect(refs.contains(URL(string: "https://example.com/a")!))
    #expect(refs.contains(URL(fileURLWithPath: "/tmp/a b.pdf")))
    #expect(refs.contains(URL(fileURLWithPath: "/tmp/file.txt")))
    #expect(!refs.contains { !["http", "https", "file"].contains($0.scheme ?? "") })
    #expect(EntryReferences.urls(in: "file://remote-host/share.txt").isEmpty)
}

@Test func finderFileURLsRoundTripThroughNamedPasteboard() throws {
    let pb = NSPasteboard(name: .init("ClipboardMaster.Files.\(UUID().uuidString)"))
    defer { pb.releaseGlobally() }
    let urls = [URL(fileURLWithPath: "/tmp/demo one.pdf"), URL(fileURLWithPath: "/tmp/demo-two.png")]
    #expect(pb.writeObjects(urls as [NSURL]))
    let adapter = SystemPasteboard(pasteboard: pb)
    let expected = ClipboardContent.text(urls.map(\.absoluteString).joined(separator: "\n"))
    #expect(adapter.readContent() == expected)
    #expect(adapter.writeReportingSuccess(expected))
    let read = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
    #expect(read == urls)
    #expect(pb.string(forType: .string) == urls.map(\.absoluteString).joined(separator: "\n"))
}

@Test func localReferencesNormalizeParentSegmentsForFinder() {
    let text = "file:///tmp/parent/../preview.txt"
    #expect(EntryReferences.urls(in: text) == [URL(fileURLWithPath: "/tmp/preview.txt")])
    #expect(EntryReferences.fileURLs(in: text) == [URL(fileURLWithPath: "/tmp/preview.txt")])
}
