namespace Hoply.Desktop.Core.SystemProxy;

/// <summary>Sistemas donde no se sabe configurar el proxy: la conexión funciona, pero cada app se configura a mano.</summary>
public sealed class UnsupportedSystemProxy : ISystemProxyConfigurator
{
    public string Platform => "unsupported";

    public bool IsSupported => false;

    public Task<SystemProxySnapshot> CaptureAsync(CancellationToken cancellationToken) =>
        throw new NotSupportedException();

    public Task ApplyAsync(string pacUrl, CancellationToken cancellationToken) =>
        throw new NotSupportedException();

    public Task RestoreAsync(SystemProxySnapshot snapshot, CancellationToken cancellationToken) =>
        throw new NotSupportedException();
}
