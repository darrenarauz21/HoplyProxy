using System.Net;
using System.Net.Sockets;

namespace Hoply.Desktop.Core.Usbmux;

/// <summary>
/// Dónde escucha usbmuxd. En Windows lo instala Apple Devices o iTunes (TCP 27015); en macOS viene con el sistema y en
/// Linux con el paquete usbmuxd (socket Unix). USBMUXD_SOCKET_ADDRESS lo cambia, como en libimobiledevice y go-ios.
/// </summary>
public static class UsbmuxEndpoint
{
    public const string OverrideVariable = "USBMUXD_SOCKET_ADDRESS";
    private const int WindowsPort = 27015;
    private const string UnixSocketPath = "/var/run/usbmuxd";
    private const string UnixPrefix = "UNIX:";

    public static EndPoint Resolve() =>
        TryParse(Environment.GetEnvironmentVariable(OverrideVariable)) ?? Default();

    public static EndPoint Default() => OperatingSystem.IsWindows()
        ? new IPEndPoint(IPAddress.Loopback, WindowsPort)
        : new UnixDomainSocketEndPoint(UnixSocketPath);

    /// <summary>Acepta «UNIX:/ruta» o «IP:puerto»; cualquier otro valor se ignora.</summary>
    public static EndPoint? TryParse(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }
        var trimmed = value.Trim();
        if (trimmed.StartsWith(UnixPrefix, StringComparison.OrdinalIgnoreCase))
        {
            var path = trimmed[UnixPrefix.Length..];
            return Path.IsPathRooted(path) ? new UnixDomainSocketEndPoint(path) : null;
        }
        return IPEndPoint.TryParse(trimmed, out var endpoint) && endpoint.Port > 0 ? endpoint : null;
    }
}
