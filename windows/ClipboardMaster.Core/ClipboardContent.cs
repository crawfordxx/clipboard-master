namespace ClipboardMaster.Core;

/// <summary>剪贴板内容：文本或图片。相等性：文本按字符；图片仅按数据字节。</summary>
public abstract record ClipboardContent
{
    /// <summary>直接构造文本内容（已信任输入，用于内部回放）。外部输入请用 <see cref="Make"/>。</summary>
    public static TextContent FromText(string text) => new(text);

    /// <summary>边界校验工厂：trim 后非空，超长截断。</summary>
    public static TextContent? Make(string text)
    {
        var trimmed = text.Trim();
        if (trimmed.Length == 0) return null;
        return trimmed.Length > HistoryLimits.StoredTextCap
            ? new TextContent(trimmed[..HistoryLimits.StoredTextCap])
            : new TextContent(trimmed);
    }

    /// <summary>边界校验工厂：数据非空、宽高为正。</summary>
    public static ImageContent? Make(byte[] imageData, int pixelWidth, int pixelHeight)
    {
        if (imageData.Length == 0 || pixelWidth <= 0 || pixelHeight <= 0) return null;
        return new ImageContent(imageData, pixelWidth, pixelHeight);
    }
}

public sealed record TextContent(string Text) : ClipboardContent;

/// <summary>图片相等性仅比较字节数据（尺寸不参与），与 macOS 版语义一致。</summary>
public sealed record ImageContent(byte[] ImageData, int PixelWidth, int PixelHeight) : ClipboardContent
{
    public bool Equals(ImageContent? other) =>
        other is not null && ImageData.AsSpan().SequenceEqual(other.ImageData);

    public override int GetHashCode()
    {
        var hash = new HashCode();
        hash.AddBytes(ImageData);
        return hash.ToHashCode();
    }
}
