using System.Diagnostics;
using ClipboardMaster.Core;
using Microsoft.Win32;

namespace ClipboardMaster.App;

/// <summary>
/// 托盘应用核心：NotifyIcon 菜单 + 剪贴板监听 + 历史存储与持久化、历史窗口编排。
/// 所有操作在 UI 线程。
/// </summary>
internal sealed class TrayContext : ApplicationContext, IHistoryActions
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string RunValueName = "ClipboardMaster";
    private const string RepoSlug = "crawfordxx/clipboard-master";

    // 密码管理器（1Password 等）标记的「不应记录」格式名
    private static readonly string[] ExcludedFormats =
    {
        "ExcludeClipboardContentFromMonitorProcessing",
        "CanIncludeInClipboardHistory",
    };

    private readonly HistoryStore _store;
    private readonly HistoryPersistence _persistence;
    private readonly ClipboardListener _listener;
    private readonly NotifyIcon _notifyIcon;
    private HistoryForm? _historyForm;
    private bool _suppressNextChange;
    private string? _latestVersion;
    private string? _sourceClonePath;
    private readonly SynchronizationContext _ui;

    public TrayContext()
    {
        _ = new Control(); // 触发 WinForms 同步上下文安装，供后台线程回 UI
        _ui = SynchronizationContext.Current ?? new SynchronizationContext();
        var directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "ClipboardMaster");
        ReadSourceManifest();
        _persistence = new HistoryPersistence(directory);
        _store = new HistoryStore(_persistence.Load());
        _listener = new ClipboardListener();
        _listener.ClipboardChanged += OnClipboardChanged;

        _notifyIcon = new NotifyIcon
        {
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath)
                ?? SystemIcons.Application,
            Text = @"Clipboard Master 剪贴板历史",
            Visible = true,
        };
        RebuildMenu();

        // 支持 --open-window 启动参数直接打开历史窗口（供 Agent 验证）
        if (Environment.GetCommandLineArgs().Contains("--open-window"))
        {
            OpenHistoryWindow();
        }

        // 启动后静默检查更新（后台线程，结果回 UI 线程）
        ThreadPool.QueueUserWorkItem(_ => CheckForUpdatesAsync(manual: false).Wait());
    }

    // ---- 剪贴板事件 ----

    private void OnClipboardChanged(object? sender, EventArgs e)
    {
        if (_suppressNextChange)
        {
            _suppressNextChange = false; // 点击历史条目写回的自我变更，吞掉
            return;
        }
        if (ExcludedCheck()) return;
        var content = ReadContent();
        if (content is null) return;
        _store.Insert(content);
        SaveAndRebuild();
    }

    private static bool ExcludedCheck()
    {
        foreach (var format in ExcludedFormats)
        {
            if (Clipboard.ContainsData(format)) return true;
        }
        return false;
    }

    private static ClipboardContent? ReadContent()
    {
        try
        {
            if (Clipboard.ContainsText())
            {
                return ClipboardContent.Make(Clipboard.GetText());
            }
            if (Clipboard.ContainsImage())
            {
                using var source = Clipboard.GetImage();
                if (source is null) return null;
                using var pngStream = new MemoryStream();
                source.Save(pngStream, System.Drawing.Imaging.ImageFormat.Png);
                return ClipboardContent.Make(
                    pngStream.ToArray(), source.Width, source.Height);
            }
        }
        catch (Exception ex) when (ex is InvalidOperationException or OutOfMemoryException)
        {
            // 剪贴板被占用（其他进程正在写入）等情况：跳过本轮
            return null;
        }
        return null;
    }

    // ---- 动作实现（托盘菜单与历史窗口共用） ----

    void IHistoryActions.CopyEntry(Guid id) => CopyEntryById(id);

    void IHistoryActions.DeleteEntry(Guid id)
    {
        _store.Remove(id);
        SaveAndRebuild();
    }

    void IHistoryActions.RevealEntry(Guid id) => RevealEntryById(id);

    void IHistoryActions.ClearAll() => OnClearHistory(this, EventArgs.Empty);

    private void CopyEntryById(Guid id)
    {
        var entry = _store.Entry(id);
        if (entry is null) return;
        _suppressNextChange = true;
        try
        {
            switch (entry.Content)
            {
                case TextContent t:
                    Clipboard.SetText(t.Text);
                    break;
                case ImageContent img:
                    using (var ms = new MemoryStream(img.ImageData))
                    {
                        Clipboard.SetImage(Image.FromStream(ms));
                    }
                    break;
            }
        }
        catch (System.Runtime.InteropServices.ExternalException)
        {
            _suppressNextChange = false;
        }
    }

    /// <summary>在资源管理器中定位图片条目的落盘文件。</summary>
    private void RevealEntryById(Guid id)
    {
        var entry = _store.Entry(id);
        var path = entry is null ? null : _persistence.GetImageFilePath(entry);
        if (path is null) return;
        Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{path}\"")
        {
            UseShellExecute = true,
        });
    }

    // ---- 菜单动作 ----

    private void OnCopyEntry(object? sender, EventArgs e)
    {
        if (sender is ToolStripMenuItem item && item.Tag is Guid id)
        {
            CopyEntryById(id);
        }
    }

    private void OnRevealEntry(object? sender, EventArgs e)
    {
        if (sender is ToolStripMenuItem item && item.Tag is Guid id)
        {
            RevealEntryById(id);
        }
    }

    private void OpenHistoryWindow(object? sender, EventArgs e) => OpenHistoryWindow();

    private void OpenHistoryWindow()
    {
        if (_historyForm is null || _historyForm.IsDisposed)
        {
            _historyForm = new HistoryForm(this);
            _historyForm.FormClosed += (_, _) => _historyForm = null;
            _historyForm.SetEntries(_store.Entries);
        }
        _historyForm.Show();
        _historyForm.Activate();
    }

    private void OnClearHistory(object? sender, EventArgs e)
    {
        _store.RemoveAll();
        try
        {
            _persistence.ClearAll();
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[ClipboardMaster] 清空历史失败: {ex}");
        }
        RebuildMenu();
    }

    private void OnToggleLaunchAtLogin(object? sender, EventArgs e)
    {
        try
        {
            using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath, writable: true);
            if (key.GetValue(RunValueName) is null)
            {
                key.SetValue(RunValueName, $"\"{Application.ExecutablePath}\"");
            }
            else
            {
                key.DeleteValue(RunValueName);
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[ClipboardMaster] 切换开机自启动失败: {ex}");
        }
        RebuildMenu();
    }

    private void OnQuit(object? sender, EventArgs e)
    {
        _notifyIcon.Visible = false;
        ExitThread();
    }

    // ---- 更新 ----

    private void ReadSourceManifest()
    {
        try
        {
            var path = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "ClipboardMaster", "source.json");
            if (!File.Exists(path)) return;
            using var doc = System.Text.Json.JsonDocument.Parse(File.ReadAllText(path));
            if (doc.RootElement.TryGetProperty("clonePath", out var clonePath))
            {
                _sourceClonePath = clonePath.GetString();
            }
        }
        catch (Exception)
        {
            // 清单缺失/损坏：不影响主功能，仅无法自更新
        }
    }

    private static string CurrentVersion()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "VERSION");
        return File.Exists(path) ? File.ReadAllText(path).Trim() : "0.0.0";
    }

    private void OnCheckForUpdates(object? sender, EventArgs e)
    {
        _ = CheckForUpdatesAsync(manual: true);
    }

    private async Task CheckForUpdatesAsync(bool manual)
    {
        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(8) };
            http.DefaultRequestHeaders.UserAgent.ParseAdd("ClipboardMaster");
            var json = await http.GetStringAsync($"https://api.github.com/repos/{RepoSlug}/releases/latest");
            using var doc = System.Text.Json.JsonDocument.Parse(json);
            var tag = doc.RootElement.GetProperty("tag_name").GetString()?.TrimStart('v');
            var hasUpdate = tag is not null && Versioning.IsNewer(CurrentVersion(), tag);
            _ui.Post(_ =>
            {
                _latestVersion = hasUpdate ? tag : null;
                RebuildMenu();
                if (manual)
                {
                    var message = hasUpdate
                        ? $"发现新版本 v{tag}（当前 v{CurrentVersion()}），托盘菜单中点击「🆕 更新到 v{tag}」即可自动更新。"
                        : $"已是最新版本 v{CurrentVersion()}。";
                    MessageBox.Show(message, @"Clipboard Master 更新",
                        MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
            }, null);
        }
        catch (Exception)
        {
            if (manual)
            {
                _ui.Post(_ => MessageBox.Show(
                    "检查更新失败：网络不可用或 GitHub 无法访问。",
                    @"Clipboard Master 更新",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning), null);
            }
        }
    }

    private void OnStartUpdate(object? sender, EventArgs e)
    {
        var tag = _latestVersion;
        if (tag is null) return;
        var clone = _sourceClonePath;
        var script = clone is null ? null : Path.Combine(clone, "scripts", "update.ps1");
        if (clone is null || !Directory.Exists(Path.Combine(clone, ".git")) ||
            script is null || !File.Exists(script))
        {
            // 克隆丢失：回退打开 Releases 页，交给用户/Agent 处理
            Process.Start(new ProcessStartInfo
            {
                FileName = $"https://github.com/{RepoSlug}/releases/latest",
                UseShellExecute = true,
            });
            return;
        }
        Process.Start(new ProcessStartInfo("powershell",
            $"-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"{script}\" -CloneDir \"{clone}\" -Tag {tag}")
        {
            UseShellExecute = false,
            CreateNoWindow = true,
        });
    }

    private bool IsLaunchAtLoginEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath);
        return key?.GetValue(RunValueName) is not null;
    }

    // ---- 菜单构建 ----

    private void SaveAndRebuild()
    {
        try
        {
            _persistence.Save(_store.Entries);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[ClipboardMaster] 保存历史失败（内存不受影响）: {ex}");
        }
        RebuildMenu();
    }

    private void RebuildMenu()
    {
        var oldMenu = _notifyIcon.ContextMenuStrip;
        var menu = new ContextMenuStrip
        {
            ImageScalingSize = new Size(32, 32),
            ShowImageMargin = true,
        };

        if (_store.Entries.Count == 0)
        {
            menu.Items.Add(new ToolStripMenuItem("暂无记录") { Enabled = false });
        }
        else
        {
            foreach (var entry in _store.Entries)
            {
                var item = new ToolStripMenuItem(PreviewFormatter.MenuTitle(entry.Content))
                {
                    ToolTipText = PreviewFormatter.Tooltip(entry),
                };
                if (entry.Content is ImageContent img)
                {
                    item.Image = MakeMenuThumbnail(img);
                    // 图片条目：主点击复制 + 子菜单可定位文件
                    item.Tag = entry.Id;
                    item.Click += OnCopyEntry;
                    var copySub = new ToolStripMenuItem("复制到剪贴板") { Tag = entry.Id };
                    copySub.Click += OnCopyEntry;
                    var revealSub = new ToolStripMenuItem("在资源管理器中显示") { Tag = entry.Id };
                    revealSub.Click += OnRevealEntry;
                    item.DropDownItems.AddRange(new ToolStripItem[] { copySub, revealSub });
                }
                else
                {
                    item.Tag = entry.Id;
                    item.Click += OnCopyEntry;
                }
                menu.Items.Add(item);
            }
        }

        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem("打开历史窗口", null, OpenHistoryWindow));
        menu.Items.Add(new ToolStripMenuItem("清空历史", null, OnClearHistory));
        menu.Items.Add(new ToolStripMenuItem("开机自启动", null, OnToggleLaunchAtLogin)
        {
            Checked = IsLaunchAtLoginEnabled(),
        });
        menu.Items.Add(new ToolStripSeparator());
        if (_latestVersion is not null)
        {
            menu.Items.Add(new ToolStripMenuItem($"🆕 更新到 v{_latestVersion}（自动重启）", null, OnStartUpdate));
        }
        menu.Items.Add(new ToolStripMenuItem("检查更新…", null, OnCheckForUpdates));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem("退出 Clipboard Master", null, OnQuit));

        _notifyIcon.ContextMenuStrip = menu;
        oldMenu?.Dispose();

        if (_historyForm is { IsDisposed: false })
        {
            _historyForm.SetEntries(_store.Entries);
        }
    }

    private static Image? MakeMenuThumbnail(ImageContent content)
    {
        try
        {
            using var ms = new MemoryStream(content.ImageData);
            using var source = Image.FromStream(ms);
            var maxHeight = 32f;
            var ratio = maxHeight / Math.Max(source.Height, 1);
            var thumbnail = new Bitmap(
                Math.Max(1, (int)(source.Width * ratio)),
                (int)maxHeight);
            thumbnail.SetResolution(96, 96);
            using var g = Graphics.FromImage(thumbnail);
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
            g.DrawImage(source, new Rectangle(0, 0, thumbnail.Width, thumbnail.Height));
            return thumbnail;
        }
        catch (Exception)
        {
            return null;
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _listener.Dispose();
            _notifyIcon.Dispose();
        }
        base.Dispose(disposing);
    }
}
