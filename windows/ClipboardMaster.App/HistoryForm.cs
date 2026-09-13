using ClipboardMaster.Core;

namespace ClipboardMaster.App;

/// <summary>历史窗口的动作接口（由 TrayContext 实现，避免窗体反向依赖控制器细节）。</summary>
internal interface IHistoryActions
{
    void CopyEntry(Guid id);
    void DeleteEntry(Guid id);
    void RevealEntry(Guid id);
    void ClearAll();
}

/// <summary>完整历史窗口：搜索 + 列表（双击复制/右键菜单）+ 底部统计与清空。</summary>
internal sealed class HistoryForm : Form
{
    private const int ThumbSize = 32;

    private readonly IHistoryActions _actions;
    private IReadOnlyList<ClipboardEntry> _entries = Array.Empty<ClipboardEntry>();

    private readonly TextBox _search = new();
    private readonly ListView _list = new();
    private readonly ImageList _thumbs = new();
    private readonly Label _count = new();
    private readonly Button _clearButton = new();
    private readonly ToolStripMenuItem _copyMenu = new("复制到剪贴板");
    private readonly ToolStripMenuItem _revealMenu = new("在资源管理器中显示");
    private readonly ToolStripMenuItem _deleteMenu = new("删除");

    public HistoryForm(IHistoryActions actions)
    {
        _actions = actions;
        Text = @"Clipboard Master · 历史记录";
        MinimumSize = new Size(520, 560);
        Size = new Size(560, 640);
        StartPosition = FormStartPosition.CenterScreen;

        BuildUi();
        WireEvents();
        ReapplyFilter();
    }

    /// <summary>历史变化时由 TrayContext 调用（UI 线程）。</summary>
    public void SetEntries(IReadOnlyList<ClipboardEntry> entries)
    {
        _entries = entries;
        ReapplyFilter();
    }

    // ---- UI 构建 ----

    private void BuildUi()
    {
        _search.Dock = DockStyle.Top;
        _search.Font = new Font("Microsoft YaHei UI", 10F);
        _search.PlaceholderText = "搜索剪贴板历史…";

        _thumbs.ImageSize = new Size(ThumbSize, ThumbSize);
        _thumbs.ColorDepth = ColorDepth.Depth32Bit;

        _list.Dock = DockStyle.Fill;
        _list.View = View.Details;
        _list.FullRowSelect = true;
        _list.HideSelection = false;
        _list.SmallImageList = _thumbs;
        _list.Columns.Add("内容", 340);
        _list.Columns.Add("时间", 130);

        var footer = new Panel { Dock = DockStyle.Bottom, Height = 40 };
        _count.Dock = DockStyle.Left;
        _count.Width = 160;
        _count.TextAlign = ContentAlignment.MiddleLeft;
        _count.ForeColor = SystemColors.GrayText;
        _clearButton.Dock = DockStyle.Right;
        _clearButton.Width = 90;
        _clearButton.Text = "清空全部";
        _clearButton.FlatStyle = FlatStyle.Flat;
        footer.Controls.Add(_count);
        footer.Controls.Add(_clearButton);

        Controls.Add(_list);
        Controls.Add(footer);
        Controls.Add(_search);

        var rowMenu = new ContextMenuStrip();
        rowMenu.Items.AddRange(new ToolStripItem[] { _copyMenu, _revealMenu,
            new ToolStripSeparator(), _deleteMenu });
        _list.ContextMenuStrip = rowMenu;
    }

    private void WireEvents()
    {
        _search.TextChanged += (_, _) => ReapplyFilter();
        _list.DoubleClick += (_, _) => CopySelected();
        _clearButton.Click += (_, _) => _actions.ClearAll();
        _copyMenu.Click += (_, _) => CopySelected();
        _deleteMenu.Click += (_, _) => DeleteSelected();
        _revealMenu.Click += (_, _) => RevealSelected();
    }

    // ---- 数据与过滤 ----

    private void ReapplyFilter()
    {
        var query = _search.Text;
        var filtered = _entries
            .Where(e => HistoryFilter.Matches(e.Content, query))
            .ToList();

        _thumbs.Images.Clear();
        _list.BeginUpdate();
        _list.Items.Clear();
        foreach (var entry in filtered)
        {
            var item = new ListViewItem(PreviewFormatter.MenuTitle(entry.Content))
            {
                Tag = entry.Id,
                UseItemStyleForSubItems = true,
            };
            if (entry.Content is ImageContent)
            {
                var thumb = MakeThumbnail(entry.Content);
                if (thumb is not null)
                {
                    _thumbs.Images.Add(thumb);
                    item.ImageIndex = _thumbs.Images.Count - 1;
                }
            }
            item.SubItems.Add(RelativeTimeFormatter.Format(entry.CapturedAt));
            _list.Items.Add(item);
        }
        _list.EndUpdate();

        _count.Text = string.IsNullOrEmpty(query)
            ? $"{_entries.Count} 条记录"
            : $"{filtered.Count} / {_entries.Count} 条";
    }

    private static Image? MakeThumbnail(ClipboardContent content)
    {
        if (content is not ImageContent img) return null;
        try
        {
            using var ms = new MemoryStream(img.ImageData);
            using var source = Image.FromStream(ms);
            var ratio = (float)ThumbSize / Math.Max(source.Width, source.Height);
            var w = Math.Max(1, (int)(source.Width * ratio));
            var h = Math.Max(1, (int)(source.Height * ratio));
            var thumb = new Bitmap(ThumbSize, ThumbSize);
            using var g = Graphics.FromImage(thumb);
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
            var x = (ThumbSize - w) / 2;
            var y = (ThumbSize - h) / 2;
            g.DrawImage(source, new Rectangle(x, y, w, h));
            return thumb;
        }
        catch (Exception)
        {
            return null;
        }
    }

    // ---- 动作 ----

    private void CopySelected()
    {
        if (_list.SelectedItems.Count > 0 && _list.SelectedItems[0].Tag is Guid id)
        {
            _actions.CopyEntry(id);
        }
    }

    private void DeleteSelected()
    {
        if (_list.SelectedItems.Count > 0 && _list.SelectedItems[0].Tag is Guid id)
        {
            _actions.DeleteEntry(id);
        }
    }

    private void RevealSelected()
    {
        if (_list.SelectedItems.Count > 0 && _list.SelectedItems[0].Tag is Guid id)
        {
            _actions.RevealEntry(id);
        }
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        _thumbs.Images.Clear();
        base.OnFormClosed(e);
    }
}
