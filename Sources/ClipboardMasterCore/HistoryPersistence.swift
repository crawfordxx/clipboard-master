import Foundation

/// 历史持久化：`history.json` 索引 + `images/<uuid>.png` 图片文件。
/// 读取端逐条校验（损坏即丢弃该条，不影响其余）；损坏 JSON 备份后从空开始。
public final class HistoryPersistence {
    private let fileManager = FileManager.default
    private let directory: URL
    private let capacity: Int

    private var indexURL: URL { directory.appendingPathComponent("history.json") }
    private var imagesURL: URL { directory.appendingPathComponent("images") }

    public init(directory: URL, capacity: Int = HistoryLimits.capacity) {
        self.directory = directory
        self.capacity = max(1, capacity)
    }

    // MARK: - 读取

    public func load() -> [ClipboardEntry] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        guard let persisted = decodeIndex(data) else {
            backupCorruptIndex()
            return []
        }
        let entries = persisted.entries.compactMap(entryFromDTO)
        return Array(entries.prefix(capacity))
    }

    // MARK: - 写入

    public func save(_ entries: [ClipboardEntry]) throws {
        try fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        let dtos = try entries.map(dtoFromEntry)
        let index = PersistedIndex(version: PersistedIndex.currentVersion, entries: dtos)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(index)
        try data.write(to: indexURL, options: .atomic)
        pruneOrphanImages(referencedBy: dtos)
    }

    public func clearAll() throws {
        try? fileManager.removeItem(at: indexURL)
        try? fileManager.removeItem(at: imagesURL)
    }

    /// 图片条目对应的磁盘文件路径（与保存命名一致：<uuid>.png）；非图片或未落盘返回 nil。
    public func imageFileURL(for entry: ClipboardEntry) -> URL? {
        guard case .image = entry.content else { return nil }
        let url = imagesURL.appendingPathComponent("\(entry.id.uuidString).png")
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    /// 目录级迁移（v1 ClipHistory → v2 ClipboardMaster）：
    /// 仅当源存在且目标不存在时整体移动；其余情况保持不动（幂等、不覆盖用户新数据）。
    public static func migrateLegacyDirectory(from source: URL, to destination: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path),
              !fm.fileExists(atPath: destination.path)
        else { return }
        do {
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: source, to: destination)
        } catch {
            FileHandle.standardError.write(
                Data("[ClipboardMaster] 历史目录迁移失败（保留原目录）: \(error)\n".utf8)
            )
        }
    }

    // MARK: - 私有：编解码

    private func decodeIndex(_ data: Data) -> PersistedIndex? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PersistedIndex.self, from: data)
    }

    private func backupCorruptIndex() {
        let backupURL = directory.appendingPathComponent("history.json.corrupt")
        try? fileManager.removeItem(at: backupURL)
        try? fileManager.moveItem(at: indexURL, to: backupURL)
        FileHandle.standardError.write(
            Data("[ClipHistory] history.json 无法解码，已备份为 history.json.corrupt，历史从空开始\n".utf8)
        )
    }

    private func entryFromDTO(_ dto: PersistedEntry) -> ClipboardEntry? {
        switch dto.kind {
        case .text(let text):
            guard let content = ClipboardContent.make(text: text) else { return nil }
            return ClipboardEntry(id: dto.id, capturedAt: dto.capturedAt, content: content)
        case .image(let file, let width, let height):
            let url = imagesURL.appendingPathComponent(file)
            guard let imageData = try? Data(contentsOf: url),
                  let content = ClipboardContent.make(imageData: imageData, pixelWidth: width, pixelHeight: height)
            else { return nil }
            return ClipboardEntry(id: dto.id, capturedAt: dto.capturedAt, content: content)
        }
    }

    private func dtoFromEntry(_ entry: ClipboardEntry) throws -> PersistedEntry {
        switch entry.content {
        case .text(let text):
            return PersistedEntry(id: entry.id, capturedAt: entry.capturedAt, kind: .text(text: text))
        case .image(let imageData, let width, let height):
            // 文件名与条目 id 绑定：重复保存同一 id 不产生新文件。
            let fileName = "\(entry.id.uuidString).png"
            let fileURL = imagesURL.appendingPathComponent(fileName)
            try imageData.write(to: fileURL, options: .atomic)
            return PersistedEntry(id: entry.id, capturedAt: entry.capturedAt, kind: .image(file: fileName, width: width, height: height))
        }
    }

    private func pruneOrphanImages(referencedBy dtos: [PersistedEntry]) {
        let referenced = Set(dtos.compactMap { dto -> String? in
            if case .image(let file, _, _) = dto.kind { return file }
            return nil
        })
        guard let files = try? fileManager.contentsOfDirectory(at: imagesURL, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files where !referenced.contains(file.lastPathComponent) {
            try? fileManager.removeItem(at: file)
        }
    }
}

// MARK: - 持久化 DTO（显式 Codable，与领域模型解耦，便于逐字段校验）

private struct PersistedIndex: Codable {
    static let currentVersion = 1

    let version: Int
    let entries: [PersistedEntry]
}

private struct PersistedEntry: Codable {
    enum Kind: Codable {
        case text(text: String)
        case image(file: String, width: Int, height: Int)
    }

    let id: UUID
    let capturedAt: Date
    let kind: Kind
}
