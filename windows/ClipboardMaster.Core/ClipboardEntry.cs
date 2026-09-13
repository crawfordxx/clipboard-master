namespace ClipboardMaster.Core;

/// <summary>一条历史记录：内容 + 捕获时间 + 稳定 Id（供菜单点击回查）。</summary>
public sealed record ClipboardEntry(Guid Id, DateTime CapturedAt, ClipboardContent Content);
