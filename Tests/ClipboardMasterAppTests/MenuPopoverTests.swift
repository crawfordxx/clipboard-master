import AppKit
import SwiftUI
import XCTest
@testable import ClipboardMasterApp

@MainActor
final class MenuPopoverTests: XCTestCase {
    func testPopoverUsesHostedContentSizeBeforePresentation() {
        _ = NSApplication.shared
        let view = MenuPanelView(model: MenuPanelModel(),
            updater: UpdateChecker(dataDirectory: FileManager.default.temporaryDirectory),
            onCopy: { _ in }, onReveal: { _ in }, onOpenHistory: {}, onClear: {},
            onToggleLogin: {}, onClose: {}, onQuit: {})
        let host = NSHostingController(rootView: view)
        let popover = NSPopover()
        popover.contentViewController = host
        let expected = host.view.fittingSize
        XCTAssertGreaterThan(expected.height, 320)
        StatusItemController.preparePopoverForDisplay(popover)
        XCTAssertEqual(popover.contentSize.width, expected.width, accuracy: 0.5)
        XCTAssertEqual(popover.contentSize.height, expected.height, accuracy: 0.5)
    }
}
