namespace ClipboardMaster.Core;

/// <summary>历史搜索过滤（大小写不敏感；文本搜全文，图片按标签）。与 macOS 版语义一致。</summary>
public static class HistoryFilter
{
    public static bool Matches(ClipboardContent content, string query)
    {
        var trimmed = query.Trim();
        if (trimmed.Length == 0) return true;
        return PreviewFormatter.MenuTitle(content).Contains(trimmed, StringComparison.OrdinalIgnoreCase)
            || (content is TextContent t
                && t.Text.Contains(trimmed, StringComparison.OrdinalIgnoreCase));
    }
}

/// <summary>相对时间描述：刚刚 / N 分钟前 / N 小时前 / N 天前；超 7 天回退日期；未来钳制为刚刚。</summary>
public static class RelativeTimeFormatter
{
    private const int FallbackDays = 7;

    public static string Format(DateTime capturedAt, DateTime? utcNow = null)
    {
        var now = utcNow ?? DateTime.UtcNow;
        var seconds = (now - capturedAt).TotalSeconds;
        if (seconds < 10) return "刚刚";
        if (seconds < 3600)
        {
            var minutes = (int)(seconds / 60);
            return minutes <= 1 ? "1 分钟前" : $"{minutes} 分钟前";
        }
        if (seconds < 86400)
        {
            var hours = (int)(seconds / 3600);
            return hours <= 1 ? "1 小时前" : $"{hours} 小时前";
        }
        if (seconds < FallbackDays * 86400)
        {
            var days = (int)(seconds / 86400);
            return days <= 1 ? "1 天前" : $"{days} 天前";
        }
        return capturedAt.ToLocalTime().ToString("yyyy-MM-dd");
    }
}
