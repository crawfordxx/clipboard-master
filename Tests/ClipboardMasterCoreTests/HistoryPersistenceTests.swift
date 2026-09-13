import Testing
import Foundation
@testable import ClipboardMasterCore

/// 每个测试用独立临时目录，teardown 清理。
private func makeTempDir() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
}

private func cleanup(_ dir: URL) {
    try? FileManager.default.removeItem(at: dir)
}

// MARK: - 往返读写

@Test func saveThenLoadRoundTripsTextAndImage() throws {
    let dir = makeTempDir()
    defer { cleanup(dir) }
    let persistence = HistoryPersistence(directory: dir)
    let image = ClipboardContent.make(imageData: Data([9, 9, 9]), pixelWidth: 8, pixelHeight: 6)!
    let entries = [
        ClipboardEntry(id: UUID(), capturedAt: Date(timeIntervalSince1970: 42), content: .text("hi")),
        ClipboardEntry(id: UUID(), capturedAt: Date(timeIntervalSince1970: 43), content: image),
    ]
    try persistence.save(entries)
    let loaded = persistence.load()
    #expect(loaded.count == 2)
    #expect(loaded[0].content == .text("hi"))
    #expect(loaded[1].content == image)
    #expect(loaded[1].capturedAt.timeIntervalSince1970 == 43)
}

// MARK: - 容错

@Test func loadMissingDirectoryReturnsEmpty() {
    let persistence = HistoryPersistence(
        directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("nope-\(UUID().uuidString)")
    )
    #expect(persistence.load().isEmpty)
}

@Test func loadCorruptJSONReturnsEmptyAndBacksUp() throws {
    let dir = makeTempDir()
    defer { cleanup(dir) }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try Data("{broken".utf8).write(to: dir.appendingPathComponent("history.json"))
    let persistence = HistoryPersistence(directory: dir)
    #expect(persistence.load().isEmpty)
    #expect(FileManager.default.fileExists(
        atPath: dir.appendingPathComponent("history.json.corrupt").path
    ))
}

@Test func loadDropsEntryWithMissingImageFile() throws {
    let dir = makeTempDir()
    defer { cleanup(dir) }
    let persistence = HistoryPersistence(directory: dir)
    try persistence.save([
        ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("keep")),
        ClipboardEntry(
            id: UUID(), capturedAt: Date(),
            content: ClipboardContent.make(imageData: Data([1, 1]), pixelWidth: 2, pixelHeight: 2)!
        ),
    ])
    let imagesDir = dir.appendingPathComponent("images")
    let files = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)
    #expect(files.count == 1)
    try FileManager.default.removeItem(at: files[0])
    let loaded = persistence.load()
    #expect(loaded.count == 1)
    #expect(loaded[0].content == .text("keep"))
}

// MARK: - 图片文件路径（reveal in Finder 用）

@Test func imageFileURLReturnsSavedFileForImageEntry() throws {
    let dir = makeTempDir()
    defer { cleanup(dir) }
    let persistence = HistoryPersistence(directory: dir)
    let entry = ClipboardEntry(
        id: UUID(), capturedAt: Date(),
        content: ClipboardContent.make(imageData: Data([7, 7]), pixelWidth: 4, pixelHeight: 4)!
    )
    try persistence.save([entry])

    let url = persistence.imageFileURL(for: entry)
    #expect(url != nil)
    #expect(FileManager.default.fileExists(atPath: url!.path))
    #expect(url!.lastPathComponent == "\(entry.id.uuidString).png")
}

@Test func imageFileURLNilForTextEntry() {
    let entry = ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("t"))
    #expect(HistoryPersistence(directory: makeTempDir()).imageFileURL(for: entry) == nil)
}

// MARK: - 目录迁移（ClipHistory → ClipboardMaster）

@Test func migrateLegacyDirectoryMovesHistory() throws {
    let legacy = makeTempDir()
    let fresh = makeTempDir()
    defer { cleanup(legacy); cleanup(fresh) }
    let legacyPersistence = HistoryPersistence(directory: legacy)
    try legacyPersistence.save([ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("legacy"))])

    HistoryPersistence.migrateLegacyDirectory(from: legacy, to: fresh)

    #expect(HistoryPersistence(directory: fresh).load().first?.content == .text("legacy"))
}

@Test func migrateLegacySkipsWhenTargetExists() throws {
    let legacy = makeTempDir()
    let fresh = makeTempDir()
    defer { cleanup(legacy); cleanup(fresh) }
    try FileManager.default.createDirectory(at: fresh, withIntermediateDirectories: true)
    try Data("x".utf8).write(to: fresh.appendingPathComponent("keep.txt"))
    let legacyPersistence = HistoryPersistence(directory: legacy)
    try legacyPersistence.save([ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("old"))])

    HistoryPersistence.migrateLegacyDirectory(from: legacy, to: fresh)

    #expect(FileManager.default.fileExists(atPath: fresh.appendingPathComponent("keep.txt").path))
}

@Test func migrateLegacyWithoutSourceIsNoop() {
    let legacy = makeTempDir() // 不创建
    let fresh = makeTempDir() // 不创建
    defer { cleanup(legacy); cleanup(fresh) }
    HistoryPersistence.migrateLegacyDirectory(from: legacy, to: fresh)
    #expect(!FileManager.default.fileExists(atPath: fresh.path))
}

// MARK: - 容量与清理

@Test func loadTrimsToCapacity() throws {
    let dir = makeTempDir()
    defer { cleanup(dir) }
    let persistence = HistoryPersistence(directory: dir, capacity: 2)
    try persistence.save(
        (0..<5).map { ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("x\($0)")) }
    )
    #expect(persistence.load().count == 2)
}

@Test func savePrunesOrphanImages() throws {
    let dir = makeTempDir()
    defer { cleanup(dir) }
    let persistence = HistoryPersistence(directory: dir)
    try persistence.save([
        ClipboardEntry(
            id: UUID(), capturedAt: Date(),
            content: ClipboardContent.make(imageData: Data([1]), pixelWidth: 1, pixelHeight: 1)!
        ),
    ])
    let imagesDir = dir.appendingPathComponent("images")
    try Data([0]).write(to: imagesDir.appendingPathComponent("orphan.png"))
    try persistence.save([ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("only text"))])
    #expect(try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil).isEmpty)
}

@Test func clearAllRemovesEverything() throws {
    let dir = makeTempDir()
    defer { cleanup(dir) }
    let persistence = HistoryPersistence(directory: dir)
    try persistence.save([ClipboardEntry(id: UUID(), capturedAt: Date(), content: .text("z"))])
    try persistence.clearAll()
    #expect(persistence.load().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("history.json").path))
}

// MARK: - 图片文件名稳定（重复保存不堆积）

@Test func resavingSameEntriesDoesNotDuplicateImageFiles() throws {
    let dir = makeTempDir()
    defer { cleanup(dir) }
    let persistence = HistoryPersistence(directory: dir)
    let entries = [
        ClipboardEntry(
            id: UUID(), capturedAt: Date(),
            content: ClipboardContent.make(imageData: Data([5, 5]), pixelWidth: 3, pixelHeight: 3)!
        ),
    ]
    try persistence.save(entries)
    try persistence.save(entries)
    let imagesDir = dir.appendingPathComponent("images")
    #expect(try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil).count == 1)
}
