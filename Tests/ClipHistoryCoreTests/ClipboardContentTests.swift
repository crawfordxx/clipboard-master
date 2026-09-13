import Testing
import Foundation
@testable import ClipHistoryCore

// MARK: - ClipboardContent.make(text:)

@Test func makeTextTrimsAndRejectsEmpty() {
    #expect(ClipboardContent.make(text: "  hello  ") == .text("hello"))
    #expect(ClipboardContent.make(text: "   \n\t ") == nil)
}

@Test func makeTextCapsLength() {
    let long = String(repeating: "a", count: HistoryLimits.storedTextCap + 50)
    let made = ClipboardContent.make(text: long)
    #expect(made == .text(String(repeating: "a", count: HistoryLimits.storedTextCap)))
}

// MARK: - ClipboardContent.make(imageData:pixelWidth:pixelHeight:)

@Test func makeImageValidates() {
    #expect(ClipboardContent.make(imageData: Data([1, 2]), pixelWidth: 10, pixelHeight: 20) != nil)
    #expect(ClipboardContent.make(imageData: Data(), pixelWidth: 10, pixelHeight: 20) == nil)
    #expect(ClipboardContent.make(imageData: Data([1]), pixelWidth: 0, pixelHeight: 20) == nil)
    #expect(ClipboardContent.make(imageData: Data([1]), pixelWidth: 10, pixelHeight: -1) == nil)
}

@Test func imageEqualityByBytes() {
    let a = ClipboardContent.make(imageData: Data([1, 2, 3]), pixelWidth: 5, pixelHeight: 5)!
    let b = ClipboardContent.make(imageData: Data([1, 2, 3]), pixelWidth: 9, pixelHeight: 9)!
    #expect(a == b)
    #expect(a != ClipboardContent.make(imageData: Data([3, 2, 1]), pixelWidth: 5, pixelHeight: 5))
}

@Test func textNotEqualToImage() {
    #expect(ClipboardContent.text("a") != ClipboardContent.make(imageData: Data([1]), pixelWidth: 1, pixelHeight: 1))
}
