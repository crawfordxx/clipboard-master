using ClipboardMaster.Core;
using Xunit;

namespace ClipboardMaster.Core.Tests;

public class ClipboardContentTests
{
    [Fact]
    public void MakeText_TrimsAndRejectsEmpty()
    {
        Assert.Equal(ClipboardContent.FromText("hello"), ClipboardContent.Make(text: "  hello  ")!);
        Assert.Null(ClipboardContent.Make(text: "   \n\t "));
    }

    [Fact]
    public void MakeText_CapsLength()
    {
        var longText = new string('a', HistoryLimits.StoredTextCap + 50);
        var made = ClipboardContent.Make(text: longText);
        Assert.Equal(new string('a', HistoryLimits.StoredTextCap), ((TextContent)made!).Text);
    }

    [Fact]
    public void MakeImage_Validates()
    {
        Assert.NotNull(ClipboardContent.Make(new byte[] { 1, 2 }, 10, 20));
        Assert.Null(ClipboardContent.Make(Array.Empty<byte>(), 10, 20));
        Assert.Null(ClipboardContent.Make(new byte[] { 1 }, 0, 20));
        Assert.Null(ClipboardContent.Make(new byte[] { 1 }, 10, -1));
    }

    [Fact]
    public void ImageEquality_ByBytes()
    {
        var a = ClipboardContent.Make(new byte[] { 1, 2, 3 }, 5, 5)!;
        var b = ClipboardContent.Make(new byte[] { 1, 2, 3 }, 9, 9)!;
        Assert.Equal(a, b);
        Assert.NotEqual(a, ClipboardContent.Make(new byte[] { 3, 2, 1 }, 5, 5));
    }
}

public class PreviewFormatterTests
{
    [Fact]
    public void CollapsedText_FoldsWhitespace()
    {
        Assert.Equal("a b c", PreviewFormatter.CollapsedText("a\n\n b \t c ", 50));
        Assert.Equal("", PreviewFormatter.CollapsedText("  ", 50));
    }

    [Fact]
    public void CollapsedText_TruncatesWithEllipsis()
    {
        Assert.Equal("abc…", PreviewFormatter.CollapsedText("abcdef", 3));
        Assert.Equal("abc", PreviewFormatter.CollapsedText("abc", 3));
    }

    [Fact]
    public void MenuTitle_TextUsesPreviewLimit()
    {
        var title = PreviewFormatter.MenuTitle(ClipboardContent.FromText(new string('x', HistoryLimits.MenuPreviewLimit + 10)));
        Assert.EndsWith("…", title);
        Assert.Equal(HistoryLimits.MenuPreviewLimit + 1, title.Length);
    }

    [Fact]
    public void MenuTitle_Image()
    {
        var c = ClipboardContent.Make(new byte[] { 1 }, 128, 64)!;
        Assert.Equal("图片 128×64", PreviewFormatter.MenuTitle(c));
    }

    [Fact]
    public void Tooltip_ContainsPreviewAndYear()
    {
        var entry = new ClipboardEntry(Guid.NewGuid(),
            new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc),
            ClipboardContent.FromText("hello"));
        var tip = PreviewFormatter.Tooltip(entry);
        Assert.Contains("hello", tip);
        Assert.Contains("1970", tip);
    }
}
