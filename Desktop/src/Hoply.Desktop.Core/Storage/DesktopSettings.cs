using Hoply.Desktop.Core.Connection;

namespace Hoply.Desktop.Core.Storage;

/// <summary>Lo último que eligió el usuario, para no tener que repetirlo.</summary>
public sealed record DesktopSettings
{
    public ConnectionMode Mode { get; init; } = ConnectionMode.Usb;

    public string WiFiHost { get; init; } = string.Empty;

    public ushort Port { get; init; } = ConnectionOptions.DefaultPort;

    public bool ConfigureSystemProxy { get; init; } = true;

    /// <summary>Variables HTTP_PROXY y HTTPS_PROXY del usuario, para Claude Code, Codex, git y otras herramientas.</summary>
    public bool ConfigureEnvironmentProxy { get; init; }

    /// <summary>Corrige valores fuera de rango de un archivo editado a mano.</summary>
    public DesktopSettings Normalized() => this with
    {
        Mode = Enum.IsDefined(Mode) ? Mode : ConnectionMode.Usb,
        WiFiHost = (WiFiHost ?? string.Empty).Trim(),
        Port = Port >= ConnectionOptions.MinimumPort ? Port : ConnectionOptions.DefaultPort,
    };
}
