import AppKit
import ClipboardMasterCore
import Foundation

/// 应用内自更新：GitHub Releases 查版本 → 拉起 scripts/update.sh（git checkout 新 tag →
/// 重跑 install.sh → 自动重启）。历史数据在独立目录，更新全程不丢。
/// 克隆丢失 / 工作区有改动时安全回退：打开 Releases 页让用户交给 Agent 处理。
final class UpdateChecker {
    static let repoSlug = "crawfordxx/clipboard-master"
    static let releasesURL = URL(string: "https://github.com/\(repoSlug)/releases/latest")!

    enum State {
        case idle
        case checking
        case upToDate
        case available(latest: String)
    }

    private(set) var state: State = .idle {
        didSet { DispatchQueue.main.async { [onStateChange] in onStateChange?() } }
    }

    var onStateChange: (() -> Void)?

    private let dataDirectory: URL
    private let defaults = UserDefaults.standard
    private let lastCheckKey = "ClipboardMaster.lastUpdateCheck"

    init(dataDirectory: URL) {
        self.dataDirectory = dataDirectory
    }

    // MARK: - 版本与来源

    var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    /// 安装时由 install.sh 写入的来源清单：{"repo": "...", "clonePath": "..."}
    var sourceClonePath: String? {
        let url = dataDirectory.appendingPathComponent("source.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object["clonePath"] as? String
    }

    // MARK: - 检查

    /// 启动时调用：距上次检查超过 24h 才静默检查。
    func checkAutomaticallyIfNeeded() {
        let last = defaults.double(forKey: lastCheckKey)
        let now = Date().timeIntervalSince1970
        guard now - last > 86_400 else { return }
        checkNow(silent: true)
    }

    func checkNow(silent: Bool = false) {
        state = .checking
        defaults.set(Date().timeIntervalSince1970, forKey: lastCheckKey)

        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repoSlug)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ClipboardMaster", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self else { return }
            self.state = self.nextState(data: data, error: error)
        }.resume()
    }

    private func nextState(data: Data?, error: Error?) -> State {
        guard error == nil, let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = object["tag_name"] as? String
        else { return .idle } // 网络失败：不打扰用户，下次再查
        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return Versioning.isNewer(current: currentVersion, latest: latest)
            ? .available(latest: latest)
            : .upToDate
    }

    var availableVersion: String? {
        if case let .available(latest) = state { return latest }
        return nil
    }

    // MARK: - 执行更新

    /// 拉起独立更新脚本（应用随后会被脚本重启，sh 进程独立存活）。
    /// 无有效克隆时回退为打开 Releases 页。
    func startUpdate() {
        guard let latest = availableVersion else { return }
        guard let clonePath = sourceClonePath,
              FileManager.default.fileExists(atPath: clonePath + "/.git")
        else {
            NSWorkspace.shared.open(Self.releasesURL)
            return
        }

        let script = clonePath + "/scripts/update.sh"
        guard FileManager.default.fileExists(atPath: script) else {
            NSWorkspace.shared.open(Self.releasesURL)
            return
        }

        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        let logURL = dataDirectory.appendingPathComponent("update.log")
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        guard let logHandle = try? FileHandle(forWritingTo: logURL) else {
            NSWorkspace.shared.open(Self.releasesURL)
            return
        }
        _ = try? logHandle.seekToEnd()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [script, clonePath, latest]
        process.standardOutput = logHandle
        process.standardError = logHandle
        do {
            try process.run()
        } catch {
            logHandle.closeFile()
            NSWorkspace.shared.open(Self.releasesURL)
        }
    }
}
