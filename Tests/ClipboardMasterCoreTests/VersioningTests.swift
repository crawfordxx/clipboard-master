import Testing
import Foundation
@testable import ClipboardMasterCore

@Test func isNewerBasics() {
    #expect(Versioning.isNewer(current: "2.1.0", latest: "2.2.0"))
    #expect(Versioning.isNewer(current: "2.1.0", latest: "v3.0.0"))
    #expect(!Versioning.isNewer(current: "2.1.0", latest: "2.1.0"))
    #expect(Versioning.isNewer(current: "2.1.0", latest: "2.1.1"))
    #expect(!Versioning.isNewer(current: "2.1.0", latest: "2.0.9"))
    #expect(Versioning.isNewer(current: "2.9.9", latest: "2.10.0")) // 数值比较，非字符串比较
    #expect(Versioning.isNewer(current: "2.1.0", latest: "3.0.0-beta"))
}

@Test func isNewerMalformedIsSafe() {
    #expect(!Versioning.isNewer(current: "2.1.0", latest: ""))
    #expect(!Versioning.isNewer(current: "2.1.0", latest: "abc"))
    #expect(!Versioning.isNewer(current: "", latest: "2.2.0"))
    #expect(!Versioning.isNewer(current: "2.1.0", latest: "not-a-version"))
}
