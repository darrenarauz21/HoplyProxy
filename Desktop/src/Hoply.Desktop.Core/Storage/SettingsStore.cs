namespace Hoply.Desktop.Core.Storage;

public interface ISettingsStore
{
    DesktopSettings Load();

    void Save(DesktopSettings settings);
}

public sealed class SettingsStore : ISettingsStore
{
    private readonly string _path;

    public SettingsStore(string path)
    {
        _path = path;
    }

    public DesktopSettings Load() =>
        (JsonFile.Read(_path, StorageJsonContext.Default.DesktopSettings) ?? new DesktopSettings()).Normalized();

    public void Save(DesktopSettings settings)
    {
        try
        {
            JsonFile.Write(_path, settings, StorageJsonContext.Default.DesktopSettings);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            // Perder los ajustes no impide conectarse: la próxima vez se usan los valores por defecto.
        }
    }
}
