import Testing
import Foundation
@testable import ClipboardMasterCore

/// 测试替身：不触碰真实 NSPasteboard。
final class FakePasteboard: PasteboardReading {
    var changeCount = 0
    var scripted: ClipboardContent?
    private(set) var written: [ClipboardContent] = []

    func readContent() -> ClipboardContent? { scripted }

    func write(_ content: ClipboardContent) {
        written.append(content)
        changeCount += 1
    }
}

// MARK: - 变更检测

@Test func pollWithoutChangeEmitsNothing() {
    let pasteboard = FakePasteboard()
    let monitor = PasteboardMonitor(pasteboard: pasteboard)
    var received: [ClipboardContent] = []
    monitor.onNewContent = { received.append($0) }
    monitor.poll()
    #expect(received.isEmpty)
}

@Test func pollEmitsNewContentOnChange() {
    let pasteboard = FakePasteboard()
    let monitor = PasteboardMonitor(pasteboard: pasteboard)
    var received: [ClipboardContent] = []
    monitor.onNewContent = { received.append($0) }

    pasteboard.scripted = .text("new")
    pasteboard.changeCount += 1
    monitor.poll()
    #expect(received == [.text("new")])
}

@Test func repeatedPollWithoutChangeEmitsOnce() {
    let pasteboard = FakePasteboard()
    let monitor = PasteboardMonitor(pasteboard: pasteboard)
    var count = 0
    monitor.onNewContent = { _ in count += 1 }

    pasteboard.scripted = .text("x")
    pasteboard.changeCount += 1
    monitor.poll()
    monitor.poll()
    monitor.poll()
    #expect(count == 1)
}

// MARK: - 不可读/隐藏内容

@Test func pollSkipsUnreadableOrConcealedContent() {
    let pasteboard = FakePasteboard()
    let monitor = PasteboardMonitor(pasteboard: pasteboard)
    var received: [ClipboardContent] = []
    monitor.onNewContent = { received.append($0) }

    pasteboard.scripted = nil // 模拟隐藏类型或空内容
    pasteboard.changeCount += 1
    monitor.poll()
    #expect(received.isEmpty)
}

// MARK: - 自我写回忽略

@Test func ignoreNextChangeSwallowsOwnWrite() {
    let pasteboard = FakePasteboard()
    let monitor = PasteboardMonitor(pasteboard: pasteboard)
    var received: [ClipboardContent] = []
    monitor.onNewContent = { received.append($0) }

    pasteboard.write(.text("self")) // changeCount +1，模拟点击历史条目写回
    monitor.ignoreNextChange()
    monitor.poll()
    #expect(received.isEmpty)
}

@Test func externalChangeAfterOwnWriteStillCaptured() {
    let pasteboard = FakePasteboard()
    let monitor = PasteboardMonitor(pasteboard: pasteboard)
    var received: [ClipboardContent] = []
    monitor.onNewContent = { received.append($0) }

    pasteboard.write(.text("self"))
    monitor.ignoreNextChange()
    monitor.poll()

    pasteboard.scripted = .text("external")
    pasteboard.changeCount += 1
    monitor.poll()
    #expect(received == [.text("external")])
}
