import AppKit
import ClipboardMasterCore
import Combine
import Foundation

/// UI state is delivered on the main queue; checks and installs are single-flight.
final class UpdateChecker: ObservableObject {
    static let repoSlug = "crawfordxx/clipboard-master"
    static let releasesURL = URL(string: "https://github.com/\(repoSlug)/releases/latest")!

    enum State: Equatable {
        case idle, checking, upToDate
        case available(latest: String)
        case installing(latest: String)
        case manualInstall(latest: String)
        case failed(message: String)
    }

    @Published private(set) var state: State = .idle {
        didSet { onStateChange?() }
    }
    var onStateChange: (() -> Void)?
    var beforeInstall: (() -> Bool)?
    private let dataDirectory: URL
    private let defaults: UserDefaults
    private let version: String?
    private let requestData: (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> Void
    private let lastCheckKey = "ClipboardMaster.lastUpdateCheck"
    private var updateProcess: Process?

    init(dataDirectory: URL, defaults: UserDefaults = .standard, version: String? = nil,
         requestData: @escaping (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> Void = {
             URLSession.shared.dataTask(with: $0, completionHandler: $1).resume()
         }) {
        self.dataDirectory = dataDirectory
        self.defaults = defaults
        self.version = version
        self.requestData = requestData
    }

    var currentVersion: String {
        version ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    var sourceClonePath: String? {
        let url = dataDirectory.appendingPathComponent("source.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object["clonePath"] as? String
    }

    var isBusy: Bool {
        switch state {
        case .checking, .installing: return true
        default: return false
        }
    }

    func checkAutomaticallyIfNeeded() {
        guard Date().timeIntervalSince1970 - defaults.double(forKey: lastCheckKey) > 86_400 else { return }
        checkNow()
    }

    func checkNow() {
        guard !isBusy else { return }
        state = .checking
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repoSlug)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ClipboardMaster", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        requestData(request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.state = self.nextState(data: data, response: response, error: error)
                switch self.state {
                case .available, .upToDate:
                    self.defaults.set(Date().timeIntervalSince1970, forKey: self.lastCheckKey)
                default: break // A failed request must not suppress retries for a day.
                }
            }
        }
    }

    private func nextState(data: Data?, response: URLResponse?, error: Error?) -> State {
        guard error == nil else { return .failed(message: "连接失败，请检查网络后重试。") }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return .failed(message: "更新服务暂不可用，请稍后重试。")
        }
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = object["tag_name"] as? String,
              tag.range(of: "^v?[0-9]+\\.[0-9]+\\.[0-9]+$", options: .regularExpression) != nil
        else { return .failed(message: "版本信息不完整，请稍后重试。") }
        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return Versioning.isNewer(current: currentVersion, latest: latest)
            ? .available(latest: latest) : .upToDate
    }

    var availableVersion: String? {
        if case let .available(latest) = state { return latest }
        return nil
    }

    var hasUpdateLog: Bool { FileManager.default.fileExists(atPath: dataDirectory.appendingPathComponent("update.log").path) }

    func openReleasePage() { NSWorkspace.shared.open(Self.releasesURL) }
    func openUpdateLog() { NSWorkspace.shared.open(dataDirectory.appendingPathComponent("update.log")) }

    func startUpdate() {
        guard let latest = availableVersion else { return }
        guard let clonePath = sourceClonePath,
              FileManager.default.fileExists(atPath: clonePath + "/.git"),
              FileManager.default.fileExists(atPath: clonePath + "/scripts/update.sh")
        else {
            state = .manualInstall(latest: latest)
            return
        }
        guard beforeInstall?() != false else { return }
        do {
            try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
            let logURL = dataDirectory.appendingPathComponent("update.log")
            if !FileManager.default.fileExists(atPath: logURL.path) {
                guard FileManager.default.createFile(atPath: logURL.path, contents: nil) else {
                    throw CocoaError(.fileWriteUnknown)
                }
            }
            let logHandle = try FileHandle(forWritingTo: logURL)
            defer { try? logHandle.close() }
            try logHandle.seekToEnd()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [clonePath + "/scripts/update.sh", clonePath, latest]
            process.standardOutput = logHandle
            process.standardError = logHandle
            process.terminationHandler = { [weak self] process in
                DispatchQueue.main.async {
                    self?.updateProcess = nil
                    if process.terminationStatus != 0 {
                        self?.state = .failed(message: process.terminationStatus == 2
                            ? "源码有本地修改，未覆盖。请保留改动后再更新。"
                            : "安装未完成，可查看日志后重试。")
                    }
                }
            }
            updateProcess = process
            state = .installing(latest: latest)
            try process.run()
        } catch {
            updateProcess = nil
            state = .failed(message: "无法启动更新，请检查目录权限后重试。")
        }
    }
}
