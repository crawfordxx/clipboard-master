using ClipboardMaster.Core;
using Xunit;

namespace ClipboardMaster.Core.Tests;

public class HistoryStoreTests
{
    [Fact]
    public void Insert_PutsNewestFirst()
    {
        var store = new HistoryStore();
        Assert.True(store.Insert(ClipboardContent.FromText("a")));
        Assert.True(store.Insert(ClipboardContent.FromText("b")));
        Assert.Equal(
            new[] { ClipboardContent.FromText("b"), ClipboardContent.FromText("a") },
            store.Entries.Select(e => e.Content).ToArray());
    }

    [Fact]
    public void InsertDuplicate_MovesToTopAndKeepsTimestamp()
    {
        var store = new HistoryStore();
        var t0 = new DateTime(1970, 1, 1, 0, 1, 40, DateTimeKind.Utc);
        var t1 = new DateTime(1970, 1, 1, 0, 3, 20, DateTimeKind.Utc);
        Assert.True(store.Insert(ClipboardContent.FromText("a"), t0));
        store.Insert(ClipboardContent.FromText("b"), t1);
        Assert.False(store.Insert(ClipboardContent.FromText("a"), t1));
        Assert.Single(store.Entries, e => e.Content == ClipboardContent.FromText("a"));
        Assert.Equal(t0, store.Entries[0].CapturedAt);
        Assert.Equal(
            ClipboardContent.FromText("a"),
            store.Entries.First().Content); // 移到最前
    }

    [Fact]
    public void Capacity_TrimsOldest()
    {
        var store = new HistoryStore(capacity: 3);
        for (var i = 0; i < 5; i++) store.Insert(ClipboardContent.FromText($"t{i}"));
        Assert.Equal(3, store.Entries.Count);
        Assert.Equal("t4", ((TextContent)store.Entries[0].Content).Text);
    }

    [Fact]
    public void Seeding_TrimsToCapacity_NewestKept()
    {
        var entries = Enumerable.Range(0, 5)
            .Select(i => new ClipboardEntry(Guid.NewGuid(), DateTime.UtcNow,
                ClipboardContent.FromText($"e{4 - i}")))
            .ToArray(); // e4..e0 最新在前
        var store = new HistoryStore(entries, capacity: 2);
        Assert.Equal("e4", ((TextContent)store.Entries[0].Content).Text);
        Assert.Equal("e3", ((TextContent)store.Entries[1].Content).Text);
    }

    [Fact]
    public void EntryById_And_RemoveAll()
    {
        var store = new HistoryStore();
        store.Insert(ClipboardContent.FromText("x"));
        var id = store.Entries[0].Id;
        Assert.Equal(ClipboardContent.FromText("x"), store.Entry(id)!.Content);
        store.RemoveAll();
        Assert.Empty(store.Entries);
        Assert.Null(store.Entry(id));
    }
}
