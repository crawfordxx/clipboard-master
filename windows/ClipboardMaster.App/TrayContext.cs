using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using ClipboardMaster.Core;
using Microsoft.Win32;

namespace ClipboardMaster.App;

/// <summary>
/// 托盘应用核心：NotifyIcon 菜单 + 剪贴板监听 + 历史存储与持久化编排。
/// 所有操作在 UI 线程。
/// </summary>
internal sealed class TrayContext : ApplicationContext
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string RunValueName = "ClipboardMaster";

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
    private bool _suppressNextChange;

    public TrayContext()
    {
        var directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "ClipboardMaster");
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

    // ---- 菜单动作 ----

    private void OnCopyEntry(object? sender, EventArgs e)
    {
        if (sender is ToolStripMenuItem item && item.Tag is Guid id)
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
            catch (ExternalException)
            {
                _suppressNextChange = false;
            }
        }
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
        var menu = new ContextMenuStrip { ImageScalingSize = new Size(20, 20) };

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
                    Tag = entry.Id,
                };
                if (entry.Content is ImageContent img)
                {
                    item.Image = MakeThumbnail(img);
                }
                item.Click += OnCopyEntry;
                menu.Items.Add(item);
            }
        }

        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem("清空历史", null, OnClearHistory));
        menu.Items.Add(new ToolStripMenuItem("开机自启动", null, OnToggleLaunchAtLogin)
        {
            Checked = IsLaunchAtLoginEnabled(),
        });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem("退出 Clipboard Master", null, OnQuit));

        _notifyIcon.ContextMenuStrip = menu;
        oldMenu?.Dispose();
    }

    private static Image? MakeThumbnail(ImageContent content)
    {
        try
        {
            using var ms = new MemoryStream(content.ImageData);
            using var source = Image.FromStream(ms);
            var maxHeight = 20f;
            var ratio = maxHeight / Math.Max(source.Height, 1);
            var thumbnail = new Bitmap(
                Math.Max(1, (int)(source.Width * ratio)),
                (int)maxHeight);
            thumbnail.SetResolution(96, 96);
            using var g = Graphics.FromImage(thumbnail);
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
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
