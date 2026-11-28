namespace Hoply.Desktop.Core.Connection;

/// <summary>Datos de una conexión con Hoply.</summary>
/// <param name="Mode">USB o Wi-Fi.</param>
/// <param name="Host">127.0.0.1 en USB; la IP del iPhone en Wi-Fi.</param>
/// <param name="Port">Puerto configurado en la app del iPhone.</param>
/// <param name="ConfigureSystemProxy">
/// Activa el proxy automático (PAC) del sistema mientras dure la conexión; en Windows, también el proxy manual.
/// </param>
/// <param name="ConfigureEnvironmentProxy">
/// Define HTTP_PROXY y HTTPS_PROXY para el usuario mientras dure la conexión, para las herramientas que no leen el proxy
/// del sistema (Node.js, Claude Code, Codex, git…).
/// </param>
public sealed record ConnectionOptions(
    ConnectionMode Mode,
    string Host,
    ushort Port,
    bool ConfigureSystemProxy,
    bool ConfigureEnvironmentProxy = false)
{
    public const ushort DefaultPort = 1080;
    public const ushort MinimumPort = 1024;
    public const string UsbHost = "127.0.0.1";

    public static ConnectionOptions Create(
        ConnectionMode mode, string wifiHost, ushort port, bool configureSystemProxy, bool configureEnvironmentProxy = false) =>
        new(mode, mode == ConnectionMode.Usb ? UsbHost : wifiHost.Trim(), port, configureSystemProxy, configureEnvironmentProxy);

    public string ProxyAddress => $"{Host}:{Port}";

    public string PacUrl => $"http://{ProxyAddress}/proxy.pac";

    public string HttpProxyUrl => $"http://{ProxyAddress}";
}
