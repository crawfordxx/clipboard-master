import XCTest
import ClipboardMasterCore
@testable import ClipboardMasterApp

final class EntryEditorTests: XCTestCase {
    private func entry() -> ClipboardEntry { var s = HistoryStore(); s.insert(.text("original")); return s.entries[0] }

    func testDraftDoesNotSaveUntilRequestedAndCanReset() {
        var saves = 0
        let model = EntryEditorModel(entry: entry(), imageURL: nil, onSave: { _, _, _ in saves += 1 }, onCopy: { _ in true })
        model.draft = "edited"; XCTAssertTrue(model.isDirty); XCTAssertEqual(saves, 0)
        model.resetDraft(); XCTAssertEqual(model.draft, "original"); XCTAssertFalse(model.isDirty)
    }

    func testSaveFailureRetainsDraftAndPreventsCopy() {
        var copies = 0
        let model = EntryEditorModel(entry: entry(), imageURL: nil, onSave: { _, _, _ in throw EntryEditError.conflict }, onCopy: { _ in copies += 1; return true })
        model.draft = "edited"
        XCTAssertFalse(model.saveAndCopy()); XCTAssertEqual(copies, 0)
        XCTAssertTrue(model.isDirty); XCTAssertNotNil(model.error)
    }

    func testSuccessfulSaveThenCopyUsesNewBaseline() {
        var saved = ""
        let model = EntryEditorModel(entry: entry(), imageURL: nil, onSave: { _, original, draft in XCTAssertEqual(original, "original"); saved = draft }, onCopy: { _ in true })
        model.draft = "second version"
        XCTAssertTrue(model.saveAndCopy()); XCTAssertEqual(saved, "second version")
        XCTAssertFalse(model.isDirty); XCTAssertEqual(model.notice, "已复制到剪贴板")
    }

    func testRemovedEntryCannotBeSavedOrCopied() {
        var saves = 0, copies = 0
        let model = EntryEditorModel(entry: entry(), imageURL: nil, onSave: { _, _, _ in saves += 1 }, onCopy: { _ in copies += 1; return true })
        model.draft = "edited"; model.markUnavailable()
        XCTAssertFalse(model.save()); XCTAssertFalse(model.saveAndCopy()); XCTAssertEqual(saves, 0); XCTAssertEqual(copies, 0)
    }
}
