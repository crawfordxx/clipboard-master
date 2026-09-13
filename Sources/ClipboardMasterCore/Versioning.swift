import Foundation

/// 语义化版本比较（v 前缀容忍、预发布后缀容忍、数值比较、畸形输入一律返回 false）。
public enum Versioning {
    public static func isNewer(current: String, latest: String) -> Bool {
        guard let c = parse(current), let l = parse(latest) else { return false }
        if l.major != c.major { return l.major > c.major }
        if l.minor != c.minor { return l.minor > c.minor }
        return l.patch > c.patch
    }

    private static func parse(_ version: String) -> (major: Int, minor: Int, patch: Int)? {
        let trimmed = version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .dropFirst(version.hasPrefix("v") ? 1 : 0)
        // 忽略预发布后缀：2.1.0-beta → 2.1.0
        let base = trimmed.split(separator: "-").first.map(String.init) ?? String(trimmed)
        let parts = base.split(separator: ".").map { Int($0) }
        guard parts.count == 3, parts.allSatisfy({ $0 != nil })
        else { return nil }
        let numbers = parts.compactMap { $0 }
        return (numbers[0], numbers[1], numbers[2])
    }
}
