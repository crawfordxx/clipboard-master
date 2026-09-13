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

/// <summary>语义化版本比较（v 前缀容忍、预发布后缀容忍、数值比较、畸形输入一律 false）。与 macOS 版一致。</summary>
public static class Versioning
{
    public static bool IsNewer(string current, string latest)
    {
        var c = Parse(current);
        var l = Parse(latest);
        if (c is null || l is null) return false;
        if (l.Value.major != c.Value.major) return l.Value.major > c.Value.major;
        if (l.Value.minor != c.Value.minor) return l.Value.minor > c.Value.minor;
        return l.Value.patch > c.Value.patch;
    }

    private static (int major, int minor, int patch)? Parse(string version)
    {
        var trimmed = version.Trim();
        if (trimmed.StartsWith("v", StringComparison.Ordinal)) trimmed = trimmed[1..];
        var @base = trimmed.Split('-')[0];
        var parts = @base.Split('.');
        if (parts.Length != 3) return null;
        if (!int.TryParse(parts[0], out var major) ||
            !int.TryParse(parts[1], out var minor) ||
            !int.TryParse(parts[2], out var patch))
        {
            return null;
        }
        return (major, minor, patch);
    }
}
