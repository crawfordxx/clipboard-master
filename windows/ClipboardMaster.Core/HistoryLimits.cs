namespace ClipboardMaster.Core;

/// <summary>全局常量集中管理（与 macOS 版保持一致）。</summary>
public static class HistoryLimits
{
    /// <summary>历史保留条数上限。</summary>
    public const int Capacity = 200;

    /// <summary>单条文本存储字符上限（边界校验）。</summary>
    public const int StoredTextCap = 100_000;

    /// <summary>菜单条目标题预览长度。</summary>
    public const int MenuPreviewLimit = 60;

    /// <summary>悬浮提示预览长度。</summary>
    public const int TooltipPreviewLimit = 200;
}
