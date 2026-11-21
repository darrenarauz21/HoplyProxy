namespace Hoply.Desktop.Core.Connection;

/// <summary>Línea para que una terminal use el proxy (git, npm, curl…). SOCKS5 con «h» resuelve el DNS en el iPhone.</summary>
public static class TerminalProxyCommand
{
    public static string ForCurrentPlatform(ConnectionOptions options) =>
        OperatingSystem.IsWindows() ? PowerShell(options) : Posix(options);

    public static string PowerShell(ConnectionOptions options)
    {
        var http = $"http://{options.ProxyAddress}";
        return $"$env:HTTP_PROXY=\"{http}\"; $env:HTTPS_PROXY=\"{http}\"; $env:ALL_PROXY=\"socks5h://{options.ProxyAddress}\"";
    }

    public static string Posix(ConnectionOptions options)
    {
        var http = $"http://{options.ProxyAddress}";
        return $"export http_proxy={http} https_proxy={http} ALL_PROXY=socks5h://{options.ProxyAddress}";
    }
}
