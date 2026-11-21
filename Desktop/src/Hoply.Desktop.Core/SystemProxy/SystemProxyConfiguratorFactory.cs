namespace Hoply.Desktop.Core.SystemProxy;

public static class SystemProxyConfiguratorFactory
{
    public static ISystemProxyConfigurator CreateForCurrentPlatform()
    {
        if (OperatingSystem.IsWindows())
        {
            return new WindowsSystemProxy();
        }
        if (OperatingSystem.IsMacOS())
        {
            return new MacSystemProxy();
        }
        if (OperatingSystem.IsLinux())
        {
            var gnome = new GnomeSystemProxy();
            if (gnome.IsSupported)
            {
                return gnome;
            }
        }
        return new UnsupportedSystemProxy();
    }
}
