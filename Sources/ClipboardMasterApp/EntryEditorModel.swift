import AppKit
import ClipboardMasterCore

/// Main-thread editor draft; durable save and clipboard writes stay in the controller.
final class EntryEditorModel: ObservableObject {
    let entry: ClipboardEntry
    let imageURL: URL?
    let image: NSImage?
    let filePreview: NSImage?
    @Published var draft: String { didSet { notice = nil } }
    @Published private(set) var originalText: String
    @Published private(set) var available = true
    @Published var error: String?
    @Published var notice: String?
    private let onSave: (UUID, String, String) throws -> Void
    private let onCopy: (UUID) -> Bool

    init(entry: ClipboardEntry, imageURL: URL?, onSave: @escaping (UUID, String, String) throws -> Void, onCopy: @escaping (UUID) -> Bool) {
        self.entry = entry
        self.imageURL = imageURL
        self.onSave = onSave
        self.onCopy = onCopy
        if case .text(let text) = entry.content {
            self.draft = text; self.originalText = text; self.image = nil
            let files = EntryReferences.fileURLs(in: text)
            if files.count == 1, let url = files.first,
               ["png", "jpg", "jpeg", "gif", "heic", "tiff", "webp", "bmp"].contains(url.pathExtension.lowercased()),
               let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
               values.isRegularFile == true, let size = values.fileSize, size <= 25_000_000 {
                self.filePreview = NSImage(contentsOf: url)
            } else { self.filePreview = nil }
        } else if case .image(let data, _, _) = entry.content {
            self.draft = ""; self.originalText = ""; self.image = NSImage(data: data); self.filePreview = nil
        } else {
            self.draft = ""; self.originalText = ""; self.image = nil; self.filePreview = nil
        }
    }

    var isText: Bool { if case .text = entry.content { return true }; return false }
    var isFileList: Bool { !EntryReferences.fileURLs(in: originalText).isEmpty }
    var isDirty: Bool { isText && draft != originalText }
    var references: [URL] { isText ? EntryReferences.urls(in: draft) : imageURL.map { [$0.standardizedFileURL] } ?? [] }
    var validDraft: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.count <= HistoryLimits.storedTextCap }

    func resetDraft() { draft = originalText; error = nil; notice = nil }
    func markUnavailable() { available = false; error = EntryEditError.missingEntry.localizedDescription }

    @discardableResult func save() -> Bool {
        guard available else { return false }
        guard isText else { return true }
        do {
            try onSave(entry.id, originalText, draft)
            originalText = draft; error = nil; notice = "修改已保存到历史记录"
            return true
        } catch { self.error = error.localizedDescription; notice = nil; return false }
    }

    @discardableResult func saveAndCopy() -> Bool {
        guard available, !isDirty || save() else { return false }
        guard onCopy(entry.id) else { error = "复制失败，请重试。"; notice = nil; return false }
        error = nil; notice = "已复制到剪贴板"
        return true
    }
}
