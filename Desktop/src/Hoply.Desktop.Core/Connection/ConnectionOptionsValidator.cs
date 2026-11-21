using System.Net;
using System.Net.Sockets;

namespace Hoply.Desktop.Core.Connection;

public enum ConnectionIssue
{
    InvalidPort,
    InvalidHost,
}

/// <summary>Valida lo que escribe el usuario antes de tocar la red o el sistema.</summary>
public static class ConnectionOptionsValidator
{
    public static IReadOnlyList<ConnectionIssue> Validate(ConnectionOptions options)
    {
        var issues = new List<ConnectionIssue>();
        if (options.Port < ConnectionOptions.MinimumPort)
        {
            issues.Add(ConnectionIssue.InvalidPort);
        }
        if (options.Mode == ConnectionMode.WiFi && !IsUsableIPv4(options.Host))
        {
            issues.Add(ConnectionIssue.InvalidHost);
        }
        return issues;
    }

    /// <summary>Solo direcciones IPv4 completas (a.b.c.d) que puedan ser un equipo de la red local.</summary>
    public static bool IsUsableIPv4(string value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Count(c => c == '.') != 3)
        {
            return false;
        }
        if (!IPAddress.TryParse(value, out var address) || address.AddressFamily != AddressFamily.InterNetwork)
        {
            return false;
        }
        return !address.Equals(IPAddress.Any) && !address.Equals(IPAddress.Broadcast) && !IPAddress.IsLoopback(address);
    }
}
