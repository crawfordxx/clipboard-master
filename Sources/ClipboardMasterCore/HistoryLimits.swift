import Foundation

/// 全局常量集中管理，避免硬编码散落各处。
public enum HistoryLimits {
    /// 历史保留条数上限。
    public static let capacity = 200
    /// 剪贴板轮询间隔（秒）。
    public static let pollInterval: TimeInterval = 0.5
    /// 单条文本存储字符上限（边界校验）。
    public static let storedTextCap = 100_000
    /// 菜单条目标题预览长度。
    public static let menuPreviewLimit = 60
    /// 悬浮提示预览长度。
    public static let tooltipPreviewLimit = 200
}
