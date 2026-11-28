namespace Hoply.Desktop.Core.SystemProxy;

/// <summary>Configuración de proxy previa a Hoply, para dejarla como estaba al desconectar.</summary>
/// <param name="Platform">Configurador que la tomó; solo ese puede restaurarla.</param>
/// <param name="Values">Valores anteriores por clave; null significa «no estaba definido».</param>
public sealed record SystemProxySnapshot(string Platform, Dictionary<string, string?> Values);

/// <summary>
/// Activa y restaura el proxy automático (PAC) del sistema operativo. Cada plataforma puede añadir otros ajustes que
/// apunten al mismo proxy (en Windows, el proxy manual) siempre que los guarde en la captura.
/// </summary>
public interface ISystemProxyConfigurator
{
    string Platform { get; }

    bool IsSupported { get; }

    Task<SystemProxySnapshot> CaptureAsync(CancellationToken cancellationToken);

    Task ApplyAsync(string pacUrl, CancellationToken cancellationToken);

    Task RestoreAsync(SystemProxySnapshot snapshot, CancellationToken cancellationToken);
}

public sealed class SystemProxyException : Exception
{
    public SystemProxyException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }
}
