namespace ClipboardMaster.Core;

/// <summary>
/// 内存历史存储：最新在前、内容去重（重复内容移到最前并保留原时间戳）、容量淘汰最旧。
/// 内部每次操作整体重建列表，不共享可变集合。
/// </summary>
public sealed class HistoryStore
{
    private readonly int _capacity;
    private List<ClipboardEntry> _entries = new();

    public HistoryStore(int capacity = HistoryLimits.Capacity)
    {
        _capacity = Math.Max(1, capacity);
    }

    /// <param name="entries">预加载历史（最新在前，如 HistoryPersistence.Load() 输出）。</param>
    public HistoryStore(IEnumerable<ClipboardEntry> entries, int capacity = HistoryLimits.Capacity) : this(capacity)
    {
        _entries = entries.Take(_capacity).ToList();
    }

    public IReadOnlyList<ClipboardEntry> Entries => _entries;

    /// <returns>true 新增；false 内容重复（原条目移到最前，时间戳不变）。</returns>
    public bool Insert(ClipboardContent content, DateTime? at = null)
    {
        var capturedAt = at ?? DateTime.UtcNow;
        var existingIndex = _entries.FindIndex(e => e.Content.Equals(content));
        if (existingIndex >= 0)
        {
            var existing = _entries[existingIndex];
            _entries = new List<ClipboardEntry> { existing }
                .Concat(_entries.Where((_, i) => i != existingIndex))
                .ToList();
            return false;
        }
        _entries = new List<ClipboardEntry> { new(Guid.NewGuid(), capturedAt, content) }
            .Concat(_entries)
            .Take(_capacity)
            .ToList();
        return true;
    }

    public void RemoveAll() => _entries = new List<ClipboardEntry>();

    /// <summary>删除单条；不存在返回 false（幂等）。</summary>
    public bool Remove(Guid id)
    {
        var index = _entries.FindIndex(e => e.Id == id);
        if (index < 0) return false;
        _entries = _entries.Where((_, i) => i != index).ToList();
        return true;
    }

    public ClipboardEntry? Entry(Guid id) => _entries.FirstOrDefault(e => e.Id == id);
}
