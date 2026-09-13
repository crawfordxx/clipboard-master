import XCTest
@testable import ClipboardMasterApp

final class CopyFeedbackTests: XCTestCase {
    func testSuccessfulCopyMarksOnlyLatestEntry() {
        let model = MenuPanelModel()
        let first = UUID(), second = UUID()
        model.recordCopy(first, changeCount: 10)
        XCTAssertEqual(model.copiedEntryID, first)
        model.recordCopy(second, changeCount: 11)
        XCTAssertEqual(model.copiedEntryID, second)
    }

    func testSameClipboardRevisionKeepsCheckmark() {
        let model = MenuPanelModel()
        let id = UUID()
        model.recordCopy(id, changeCount: 20)
        model.synchronizeClipboard(changeCount: 20)
        XCTAssertEqual(model.copiedEntryID, id)
    }

    func testExternalClipboardChangeClearsCheckmark() {
        let model = MenuPanelModel()
        model.recordCopy(UUID(), changeCount: 20)
        model.synchronizeClipboard(changeCount: 21)
        XCTAssertNil(model.copiedEntryID)
    }

    func testFailureClearsPreviousFeedback() {
        let model = MenuPanelModel()
        model.recordCopy(UUID(), changeCount: 20)
        model.clearCopyFeedback()
        XCTAssertNil(model.copiedEntryID)
    }
}
