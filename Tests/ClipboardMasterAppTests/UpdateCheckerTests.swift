import XCTest
@testable import ClipboardMasterApp

@MainActor
final class UpdateCheckerTests: XCTestCase {
    private var completion: ((Data?, URLResponse?, Error?) -> Void)?
    private var requests = 0
    private var checker: UpdateChecker!
    private var preferences: UserDefaults!
    private let suite = "ClipboardMaster.UpdateCheckerTests"

    override func setUp() async throws {
        preferences = UserDefaults(suiteName: suite)!
        preferences.removePersistentDomain(forName: suite)
        requests = 0
        checker = UpdateChecker(dataDirectory: URL(fileURLWithPath: "/nonexistent-test-source"),
            defaults: preferences, version: "2.1.1", requestData: { _, completion in
                self.requests += 1
                self.completion = completion
            })
    }

    private func finish(_ status: Int, _ body: String) async {
        let done = expectation(description: "state delivered on main thread")
        checker.onStateChange = {
            XCTAssertTrue(Thread.isMainThread)
            if self.checker.state != .checking { done.fulfill() }
        }
        completion?(Data(body.utf8), HTTPURLResponse(url: UpdateChecker.releasesURL,
                    statusCode: status, httpVersion: nil, headerFields: nil), nil)
        await fulfillment(of: [done], timeout: 2)
        checker.onStateChange = nil
    }

    func testSlowCheckStaysCheckingAndCoalescesRepeatedClicks() async throws {
        checker.checkNow()
        checker.checkNow()
        try await Task.sleep(for: .seconds(2.7))
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(checker.state, .checking)
        await finish(200, #"{"tag_name":"v2.2.0"}"#)
        XCTAssertEqual(checker.state, .available(latest: "2.2.0"))
    }

    func testCurrentVersionAndSuccessfulCheckTimestamp() async {
        checker.checkNow()
        await finish(200, #"{"tag_name":"v2.1.1"}"#)
        XCTAssertEqual(checker.state, .upToDate)
        XCTAssertGreaterThan(preferences.double(forKey: "ClipboardMaster.lastUpdateCheck"), 0)
    }

    func testHTTPFailureIsRetryableAndDoesNotConsumeDailyCheck() async {
        checker.checkNow()
        await finish(403, #"{"message":"rate limit"}"#)
        guard case .failed = checker.state else { return XCTFail("Expected failure") }
        XCTAssertEqual(preferences.double(forKey: "ClipboardMaster.lastUpdateCheck"), 0)
        checker.checkNow()
        XCTAssertEqual(requests, 2)
        await finish(200, #"{"tag_name":"v2.2.0"}"#)
        XCTAssertEqual(checker.availableVersion, "2.2.0")
    }

    func testMalformedResponseIsNotLatestVersion() async {
        checker.checkNow()
        await finish(200, #"{"tag_name":"not-a-version"}"#)
        guard case .failed = checker.state else { return XCTFail("Invalid release must fail") }
    }

    func testMissingSourceShowsManualInstallInsteadOfSilentBrowserJump() async {
        checker.checkNow()
        await finish(200, #"{"tag_name":"v2.2.0"}"#)
        checker.startUpdate()
        XCTAssertEqual(checker.state, .manualInstall(latest: "2.2.0"))
    }
    private func installFixture(script: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let clone = directory.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: clone.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: clone.appendingPathComponent("scripts"), withIntermediateDirectories: true)
        try Data(script.utf8).write(to: clone.appendingPathComponent("scripts/update.sh"))
        try JSONSerialization.data(withJSONObject: ["clonePath": clone.path]).write(to: directory.appendingPathComponent("source.json"))
        checker = UpdateChecker(dataDirectory: directory, defaults: preferences, version: "2.1.1", requestData: { _, completion in
            self.requests += 1
            self.completion = completion
        })
        return directory
    }

    func testInstallerFailureReportsExitAndRejectsDuplicateOperations() async throws {
        let directory = try installFixture(script: "#!/bin/bash\nsleep 0.3\nprintf 'fixture stdout\\n'\nprintf 'fixture stderr\\n' >&2\nexit 2\n")
        defer { try? FileManager.default.removeItem(at: directory) }
        checker.checkNow()
        await finish(200, #"{"tag_name":"v2.2.0"}"#)
        let done = expectation(description: "installer exit delivered")
        checker.onStateChange = { if case .failed = self.checker.state { done.fulfill() } }
        checker.startUpdate()
        XCTAssertEqual(checker.state, .installing(latest: "2.2.0"))
        checker.startUpdate()
        checker.checkNow()
        XCTAssertEqual(requests, 1)
        await fulfillment(of: [done], timeout: 3)
        checker.onStateChange = nil
        XCTAssertEqual(checker.state, .failed(message: "源码有本地修改，未覆盖。请保留改动后再更新。"))
        let log = try String(contentsOf: directory.appendingPathComponent("update.log"))
        XCTAssertEqual(log, "fixture stdout\nfixture stderr\n")
        checker.checkNow()
        XCTAssertEqual(requests, 2)
    }

    func testUnwritableLogFailsWithoutLaunchingInstaller() async throws {
        let directory = try installFixture(script: "#!/bin/bash\nexit 99\n")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("update.log"), withIntermediateDirectories: true)
        checker.checkNow()
        await finish(200, #"{"tag_name":"v2.2.0"}"#)
        checker.startUpdate()
        XCTAssertEqual(checker.state, .failed(message: "无法启动更新，请检查目录权限后重试。"))
    }

    func testNetworkErrorIsExplicitAndRetryable() async {
        checker.checkNow()
        let done = expectation(description: "network failure")
        checker.onStateChange = { if case .failed = self.checker.state { done.fulfill() } }
        completion?(nil, nil, URLError(.timedOut))
        await fulfillment(of: [done], timeout: 2)
        checker.onStateChange = nil
        XCTAssertEqual(checker.state, .failed(message: "连接失败，请检查网络后重试。"))
        checker.checkNow()
        XCTAssertEqual(requests, 2)
    }

}
