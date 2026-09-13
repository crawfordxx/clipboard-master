using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace ClipboardMaster.Core;

/// <summary>
/// 历史持久化：history.json 索引 + images/{uuid}.png 图片文件。
/// JSON 形状与 macOS 版完全一致（camelCase、kind 判别式、ISO8601 无小数秒），可跨平台互读。
/// 读取端逐条校验（损坏即丢弃该条）；损坏 JSON 备份后从空开始。
/// </summary>
public sealed class HistoryPersistence
{
    private const string IndexFileName = "history.json";
    private const string ImagesDirName = "images";
    private const int CurrentVersion = 1;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new KindDtoConverter(), new SwiftDateTimeConverter() },
    };

    private readonly string _directory;
    private readonly int _capacity;

    private string IndexPath => Path.Combine(_directory, IndexFileName);
    private string ImagesPath => Path.Combine(_directory, ImagesDirName);

    public HistoryPersistence(string directory, int capacity = HistoryLimits.Capacity)
    {
        _directory = directory;
        _capacity = Math.Max(1, capacity);
    }

    public IReadOnlyList<ClipboardEntry> Load()
    {
        if (!File.Exists(IndexPath)) return Array.Empty<ClipboardEntry>();
        PersistedIndex? index;
        try
        {
            index = JsonSerializer.Deserialize<PersistedIndex>(File.ReadAllText(IndexPath), JsonOptions);
        }
        catch (JsonException)
        {
            BackupCorruptIndex();
            return Array.Empty<ClipboardEntry>();
        }
        if (index?.Entries is null) return Array.Empty<ClipboardEntry>();
        return index.Entries
            .Select(ToEntry)
            .Where(e => e is not null)
            .Take(_capacity)
            .Cast<ClipboardEntry>()
            .ToList();
    }

    public void Save(IReadOnlyList<ClipboardEntry> entries)
    {
        Directory.CreateDirectory(ImagesPath);
        var dtos = entries.Select(ToDto).ToList();
        var index = new PersistedIndex(CurrentVersion, dtos);
        AtomicWrite(IndexPath, JsonSerializer.Serialize(index, JsonOptions));
        PruneOrphanImages(dtos);
    }

    public void ClearAll()
    {
        TryDelete(IndexPath);
        if (Directory.Exists(ImagesPath)) Directory.Delete(ImagesPath, true);
    }

    /// <summary>图片条目对应的磁盘文件路径（与保存命名一致：{uuid}.png）；非图片或未落盘返回 null。</summary>
    public string? GetImageFilePath(ClipboardEntry entry)
    {
        if (entry.Content is not ImageContent) return null;
        var path = Path.Combine(ImagesPath, $"{entry.Id.ToString("D")}.png");
        return File.Exists(path) ? path : null;
    }

    // ---- 内部转换与校验 ----

    private ClipboardEntry? ToEntry(PersistedEntry dto) => dto.Kind switch
    {
        TextKindDto t => ClipboardContent.Make(t.Text) is { } c
            ? new ClipboardEntry(dto.Id, dto.CapturedAt, c)
            : null,
        ImageKindDto img => LoadImage(img) is { } c2
            ? new ClipboardEntry(dto.Id, dto.CapturedAt, c2)
            : null,
        _ => null,
    };

    private ImageContent? LoadImage(ImageKindDto dto)
    {
        var path = Path.Combine(ImagesPath, dto.File);
        if (!File.Exists(path)) return null;
        try
        {
            var bytes = File.ReadAllBytes(path);
            return ClipboardContent.Make(bytes, dto.Width, dto.Height);
        }
        catch (IOException)
        {
            return null;
        }
    }

    private PersistedEntry ToDto(ClipboardEntry entry) => entry.Content switch
    {
        TextContent t => new PersistedEntry(entry.Id, entry.CapturedAt, new TextKindDto(t.Text)),
        ImageContent img => new PersistedEntry(entry.Id, entry.CapturedAt, SaveImage(entry.Id, img)),
        _ => throw new InvalidOperationException("未知内容类型"),
    };

    private ImageKindDto SaveImage(Guid id, ImageContent img)
    {
        // 文件名与条目 Id 绑定：重复保存同一条目不产生新文件（与 mac 版一致）。
        var fileName = $"{id.ToString("D")}.png";
        AtomicWrite(Path.Combine(ImagesPath, fileName), img.ImageData);
        return new ImageKindDto(fileName, img.PixelWidth, img.PixelHeight);
    }

    private void PruneOrphanImages(List<PersistedEntry> dtos)
    {
        var referenced = dtos
            .Select(d => d.Kind as ImageKindDto)
            .Where(k => k is not null)
            .Select(k => k!.File)
            .ToHashSet();
        if (!Directory.Exists(ImagesPath)) return;
        foreach (var file in Directory.GetFiles(ImagesPath))
        {
            if (!referenced.Contains(Path.GetFileName(file))) TryDelete(file);
        }
    }

    private void BackupCorruptIndex()
    {
        var backupPath = IndexPath + ".corrupt";
        TryDelete(backupPath);
        try
        {
            File.Move(IndexPath, backupPath);
        }
        catch (IOException)
        {
            // 备份失败则保留原文件，下次启动重试
        }
    }

    private static void AtomicWrite(string path, string text) => AtomicWrite(path, Encoding.UTF8.GetBytes(text));

    private static void AtomicWrite(string path, byte[] bytes)
    {
        var tmpPath = path + ".tmp";
        File.WriteAllBytes(tmpPath, bytes);
        File.Move(tmpPath, path, overwrite: true);
    }

    private static void TryDelete(string path)
    {
        try { File.Delete(path); }
        catch (IOException) { }
    }
}

// ---- 持久化 DTO（形状与 Swift 版 Codable 输出逐字节对齐）----

internal sealed record PersistedIndex(int Version, List<PersistedEntry> Entries);

internal sealed record PersistedEntry(Guid Id, DateTime CapturedAt, KindDto Kind);

internal abstract record KindDto;

internal sealed record TextKindDto(string Text) : KindDto;

internal sealed record ImageKindDto(string File, int Width, int Height) : KindDto;

/// <summary>判别式联合：{"text":{"text":...}} / {"image":{"file":...,"width":...,"height":...}}</summary>
internal sealed class KindDtoConverter : JsonConverter<KindDto>
{
    public override KindDto Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        using var doc = JsonDocument.ParseValue(ref reader);
        var root = doc.RootElement;
        if (root.ValueKind != JsonValueKind.Object || root.EnumerateObject().Count() != 1)
            throw new JsonException("kind 应为单属性判别对象");
        var prop = root.EnumerateObject().Single();
        var value = prop.Value;
        return prop.Name switch
        {
            "text" => new TextKindDto(value.GetProperty("text").GetString() ?? ""),
            "image" => new ImageKindDto(
                value.GetProperty("file").GetString() ?? "",
                value.GetProperty("width").GetInt32(),
                value.GetProperty("height").GetInt32()),
            _ => throw new JsonException($"未知 kind: {prop.Name}"),
        };
    }

    public override void Write(Utf8JsonWriter writer, KindDto value, JsonSerializerOptions options)
    {
        writer.WriteStartObject();
        switch (value)
        {
            case TextKindDto t:
                writer.WritePropertyName("text");
                writer.WriteStartObject();
                writer.WriteString("text", t.Text);
                writer.WriteEndObject();
                break;
            case ImageKindDto img:
                writer.WritePropertyName("image");
                writer.WriteStartObject();
                writer.WriteString("file", img.File);
                writer.WriteNumber("width", img.Width);
                writer.WriteNumber("height", img.Height);
                writer.WriteEndObject();
                break;
            default:
                throw new JsonException("未知 KindDto");
        }
        writer.WriteEndObject();
    }
}

/// <summary>Swift .iso8601 兼容：写入无小数秒的 UTC；读取兼容任意 ISO8601。</summary>
internal sealed class SwiftDateTimeConverter : JsonConverter<DateTime>
{
    private const string Format = "yyyy-MM-dd'T'HH:mm:ss'Z'";

    public override DateTime Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var s = reader.GetString()
            ?? throw new JsonException("日期应为字符串");
        return DateTime.Parse(s, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind).ToUniversalTime();
    }

    public override void Write(Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options)
    {
        writer.WriteStringValue(value.ToUniversalTime().ToString(Format, CultureInfo.InvariantCulture));
    }
}
