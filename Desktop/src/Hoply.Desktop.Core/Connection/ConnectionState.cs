using System.Net;

namespace Hoply.Desktop.Core.Connection;

public enum ConnectionState
{
    Disconnected,
    Connecting,
    Connected,
    Disconnecting,
}

/// <summary>Resultado de conectar.</summary>
/// <param name="PublicAddress">IP pública vista a través del iPhone; null si no se pudo verificar.</param>
/// <param name="SystemProxyApplied">El proxy del sistema quedó configurado.</param>
public sealed record ConnectionReport(IPAddress? PublicAddress, bool SystemProxyApplied);
