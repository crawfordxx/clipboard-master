using ClipboardMaster.Core;
using Xunit;

namespace ClipboardMaster.Core.Tests;

public class HistoryExtensionTests
{
    // ---- HistoryStore.Remove ----

    [Fact]
    public void Remove_ById_PreservesOrder()
    {
        var store = new HistoryStore();
        store.Insert(ClipboardContent.FromText("a"));
        store.Insert(ClipboardContent.FromText("b"));
        store.Insert(ClipboardContent.FromText("c"));
        var idB = store.Entries[1].Id;

        Assert.True(store.Remove(idB));
        Assert.Equal(
            new[] { ClipboardContent.FromText("c"), ClipboardContent.FromText("a") },
            store.Entries.Select(e => e.Content).ToArray());
        Assert.False(store.Remove(idB)); // 已删，幂等
    }

    // ---- HistoryFilter ----

    [Fact]
    public void Filter_EmptyQuery_MatchesEverything()
    {
        var image = ClipboardContent.Make(new byte[] { 1 }, 6, 4)!;
        Assert.True(HistoryFilter.Matches(ClipboardContent.FromText("abc"), ""));
        Assert.True(HistoryFilter.Matches(ClipboardContent.FromText("abc"), "   "));
        Assert.True(HistoryFilter.Matches(image, ""));
    }

    [Fact]
    public void Filter_Text_CaseInsensitive_FullBody()
    {
        Assert.True(HistoryFilter.Matches(ClipboardContent.FromText("Hello World"), "hello"));
        Assert.True(HistoryFilter.Matches(ClipboardContent.FromText("Hello World"), "WORLD"));
        var longText = new string('x', 200) + "needle" + new string('y', 200);
        Assert.True(HistoryFilter.Matches(ClipboardContent.FromText(longText), "needle"));
        Assert.False(HistoryFilter.Matches(ClipboardContent.FromText("Hello World"), "xyz"));
    }

    [Fact]
    public void Filter_Image_ByLabel()
    {
        var image = ClipboardContent.Make(new byte[] { 1 }, 128, 64)!;
        Assert.True(HistoryFilter.Matches(image, "图片"));
        Assert.True(HistoryFilter.Matches(image, "128"));
        Assert.False(HistoryFilter.Matches(image, "hello"));
    }

    // ---- RelativeTimeFormatter ----

    [Fact]
    public void RelativeTime_Segments()
    {
        var now = new DateTime(2026, 9, 13, 12, 0, 0, DateTimeKind.Utc);
        Assert.Equal("刚刚", RelativeTimeFormatter.Format(now.AddSeconds(-5), now));
        Assert.Equal("1 分钟前", RelativeTimeFormatter.Format(now.AddSeconds(-90), now));
        Assert.Equal("2 小时前", RelativeTimeFormatter.Format(now.AddHours(-2), now));
        Assert.Equal("3 天前", RelativeTimeFormatter.Format(now.AddDays(-3), now));
        Assert.Equal("刚刚", RelativeTimeFormatter.Format(now.AddSeconds(60), now)); // 时钟偏移钳制
        Assert.Contains("2026", RelativeTimeFormatter.Format(now.AddDays(-30), now)); // 远期回退日期
    }

    // ---- HistoryPersistence.GetImageFilePath ----

    [Fact]
    public void GetImageFilePath_ReturnsSavedFile()
    {
        var dir = Path.Combine(Path.GetTempPath(), "cbm-ext-" + Guid.NewGuid().ToString("N"));
        try
        {
            var persistence = new HistoryPersistence(dir);
            var entry = new ClipboardEntry(Guid.NewGuid(), DateTime.UtcNow,
                ClipboardContent.Make(new byte[] { 7, 7 }, 4, 4)!);
            persistence.Save(new[] { entry });

            var path = persistence.GetImageFilePath(entry);
            Assert.NotNull(path);
            Assert.True(File.Exists(path));
            Assert.EndsWith($"{entry.Id.ToString("D")}.png", path);

            Assert.Null(persistence.GetImageFilePath(
                new ClipboardEntry(Guid.NewGuid(), DateTime.UtcNow, ClipboardContent.FromText("t"))));
        }
        finally
        {
            if (Directory.Exists(dir)) Directory.Delete(dir, true);
        }
    }
}
