using System.Runtime.InteropServices;

namespace ClipboardMaster.App;

/// <summary>
/// Windows 剪贴板监听：AddClipboardFormatListener + 隐藏消息窗口。
/// macOS 无通知只能轮询；Windows 有系统事件，变更即时触发。
/// </summary>
internal sealed class ClipboardListener : NativeWindow, IDisposable
{
    private const int WM_CLIPBOARDUPDATE = 0x031D;

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool AddClipboardFormatListener(IntPtr hwnd);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RemoveClipboardFormatListener(IntPtr hwnd);

    /// <summary>剪贴板内容变化（UI 线程触发）。</summary>
    public event EventHandler? ClipboardChanged;

    public ClipboardListener()
    {
        CreateHandle(new CreateParams());
        if (!AddClipboardFormatListener(Handle))
        {
            throw new InvalidOperationException(
                $"注册剪贴板监听失败 (Win32 错误 {Marshal.GetLastWin32Error()})");
        }
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_CLIPBOARDUPDATE)
        {
            ClipboardChanged?.Invoke(this, EventArgs.Empty);
        }
        base.WndProc(ref m);
    }

    public void Dispose()
    {
        RemoveClipboardFormatListener(Handle);
        DestroyHandle();
        GC.SuppressFinalize(this);
    }
}
