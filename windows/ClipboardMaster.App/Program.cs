namespace ClipboardMaster.App;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        using var context = new TrayContext();
        Application.Run(context);
    }
}
