using Hoply.Desktop.Core.SystemProxy;

namespace Hoply.Desktop.Core.Storage;

/// <summary>
/// Guarda la configuración de proxy anterior mientras Hoply la tiene cambiada. Si la app se cierra de golpe, la
/// siguiente vez que se abre la restaura y la laptop no queda apuntando a un proxy que ya no existe.
/// </summary>
public sealed class ProxyRecoveryStore
{
    private readonly string _path;

    public ProxyRecoveryStore(string path)
    {
        _path = path;
    }

    public SystemProxySnapshot? Load() => JsonFile.Read(_path, StorageJsonContext.Default.SystemProxySnapshot);

    public void Save(SystemProxySnapshot snapshot)
    {
        try
        {
            JsonFile.Write(_path, snapshot, StorageJsonContext.Default.SystemProxySnapshot);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            throw new SystemProxyException("No se pudo guardar la configuración de proxy anterior.", exception);
        }
    }

    public void Clear()
    {
        try
        {
            JsonFile.Delete(_path);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            // Si queda, se intentará restaurar de nuevo al abrir la app, lo que no cambia nada.
        }
    }
}
