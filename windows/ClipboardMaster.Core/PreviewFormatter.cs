using System.Globalization;

namespace ClipboardMaster.Core;

/// <summary>菜单展示用的文本格式化（纯函数）。</summary>
public static class PreviewFormatter
{
    /// <summary>折叠所有空白为单个空格；超长保留 limit 个字符后加省略号。</summary>
    public static string CollapsedText(string text, int limit)
    {
        var collapsed = string.Join(" ",
            text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
        if (collapsed.Length <= limit || limit <= 0) return collapsed;
        return collapsed[..limit] + "…";
    }

    /// <summary>菜单条目标题：文本走折叠预览；图片显示「图片 W×H」。</summary>
    public static string MenuTitle(ClipboardContent content) => content switch
    {
        TextContent t => CollapsedText(t.Text, HistoryLimits.MenuPreviewLimit),
        ImageContent i => $"图片 {i.PixelWidth}×{i.PixelHeight}",
        _ => "",
    };

    /// <summary>悬浮提示：本地时间 + 更长的内容预览。</summary>
    public static string Tooltip(ClipboardEntry entry)
    {
        var time = entry.CapturedAt.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture);
        var preview = entry.Content is TextContent t
            ? CollapsedText(t.Text, HistoryLimits.TooltipPreviewLimit)
            : MenuTitle(entry.Content);
        return $"{time}\n{preview}";
    }
}
