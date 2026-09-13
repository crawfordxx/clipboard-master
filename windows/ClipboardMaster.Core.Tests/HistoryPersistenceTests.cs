using ClipboardMaster.Core;
using Xunit;

namespace ClipboardMaster.Core.Tests;

public class HistoryPersistenceTests : IDisposable
{
    private readonly string _dir;

    public HistoryPersistenceTests()
    {
        _dir = Path.Combine(Path.GetTempPath(), "cbm-test-" + Guid.NewGuid().ToString("N"));
    }

    public void Dispose()
    {
        if (Directory.Exists(_dir)) Directory.Delete(_dir, true);
    }

    [Fact]
    public void SaveThenLoad_RoundTripsTextAndImage()
    {
        var persistence = new HistoryPersistence(_dir);
        var image = ClipboardContent.Make(new byte[] { 9, 9, 9 }, 8, 6)!;
        var entries = new[]
        {
            new ClipboardEntry(Guid.NewGuid(),
                new DateTime(1970, 1, 1, 0, 0, 42, DateTimeKind.Utc),
                ClipboardContent.FromText("hi")),
            new ClipboardEntry(Guid.NewGuid(),
                new DateTime(1970, 1, 1, 0, 0, 43, DateTimeKind.Utc),
                image),
        };
        persistence.Save(entries);

        var loaded = persistence.Load();
        Assert.Equal(2, loaded.Count);
        Assert.Equal(ClipboardContent.FromText("hi"), loaded[0].Content);
        Assert.Equal(image, loaded[1].Content);
        Assert.Equal(43, loaded[1].CapturedAt.Second);
    }

    [Fact]
    public void Load_MissingDirectory_ReturnsEmpty()
    {
        Assert.Empty(new HistoryPersistence(_dir).Load());
    }

    [Fact]
    public void Load_CorruptJson_ReturnsEmptyAndBacksUp()
    {
        Directory.CreateDirectory(_dir);
        File.WriteAllText(Path.Combine(_dir, "history.json"), "{broken");
        Assert.Empty(new HistoryPersistence(_dir).Load());
        Assert.True(File.Exists(Path.Combine(_dir, "history.json.corrupt")));
    }

    [Fact]
    public void Load_DropsEntryWithMissingImageFile()
    {
        var persistence = new HistoryPersistence(_dir);
        persistence.Save(new[]
        {
            new ClipboardEntry(Guid.NewGuid(), DateTime.UtcNow, ClipboardContent.FromText("keep")),
            new ClipboardEntry(Guid.NewGuid(), DateTime.UtcNow, ClipboardContent.Make(new byte[] { 1, 1 }, 2, 2)!),
        });
        var imagesDir = Path.Combine(_dir, "images");
        var files = Directory.GetFiles(imagesDir);
        Assert.Single(files);
        File.Delete(files[0]);

        var loaded = persistence.Load();
        Assert.Single(loaded);
        Assert.Equal("keep", ((TextContent)loaded[0].Content).Text);
    }

    [Fact]
    public void Load_TrimsToCapacity()
    {
        var persistence = new HistoryPersistence(_dir, capacity: 2);
        persistence.Save(Enumerable.Range(0, 5)
            .Select(i => new ClipboardEntry(Guid.NewGuid(), DateTime.UtcNow, ClipboardContent.FromText($"x{i}")))
            .ToArray());
        Assert.Equal(2, persistence.Load().Count);
    }

    [Fact]
    public void Save_PrunesOrphanImages()
    {
        var persistence = new HistoryPersistence(_dir);
        persistence.Save(new[]
        {
            new ClipboardEntry(Guid.NewGuid(), DateTime.UtcNow, ClipboardContent.Make(new byte[] { 1 }, 1, 1)!),
        });
        File.WriteAllBytes(Path.Combine(_dir, "images", "orphan.png"), new byte[] { 0 });
        persistence.Save(new[]
        {
            new ClipboardEntry(Guid.NewGuid(), DateTime.UtcNow, ClipboardContent.FromText("only text")),
        });
        Assert.Empty(Directory.GetFiles(Path.Combine(_dir, "images")));
    }

    [Fact]
    public void ClearAll_RemovesEverything()
    {
        var persistence = new HistoryPersistence(_dir);
        persistence.Save(new[] { new ClipboardEntry(Guid.NewGuid(), DateTime.UtcNow, ClipboardContent.FromText("z")) });
        persistence.ClearAll();
        Assert.Empty(persistence.Load());
        Assert.False(File.Exists(Path.Combine(_dir, "history.json")));
    }

    [Fact]
    public void SaveTwice_DoesNotDuplicateImageFiles()
    {
        var persistence = new HistoryPersistence(_dir);
        var entries = new[]
        {
            new ClipboardEntry(Guid.NewGuid(), DateTime.UtcNow, ClipboardContent.Make(new byte[] { 5, 5 }, 3, 3)!),
        };
        persistence.Save(entries);
        persistence.Save(entries);
        Assert.Single(Directory.GetFiles(Path.Combine(_dir, "images")));
    }

    [Fact]
    public void Json_IsCompatibleWithMacFormat()
    {
        // 与 Swift 版完全一致的 JSON 形状（camelCase、kind 判别式、ISO8601 无小数秒）
        var persistence = new HistoryPersistence(_dir);
        persistence.Save(new[]
        {
            new ClipboardEntry(
                Guid.Parse("AAAAAAAA-BBBB-CCCC-DDDD-000000000001"),
                new DateTime(2026, 9, 13, 3, 52, 53, DateTimeKind.Utc),
                ClipboardContent.FromText("compat")),
        });
        var json = File.ReadAllText(Path.Combine(_dir, "history.json"));
        Assert.Contains("\"version\":1", json.Replace(" ", ""));
        Assert.Contains("\"kind\":{\"text\":{\"text\":\"compat\"}}", json.Replace(" ", ""));
        Assert.Contains("2026-09-13T03:52:53Z", json);
    }
}
