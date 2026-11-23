namespace Hoply.Desktop.Core.Storage;

/// <summary>Archivos de la app en la carpeta de datos del usuario.</summary>
public sealed record AppPaths(string SettingsFile, string RecoveryFile, string EnvironmentRecoveryFile)
{
    private const string FolderName = "Hoply";

    /// <summary>Carpeta de las versiones publicadas como TetherProxy; se migra a <see cref="FolderName"/> al arrancar.</summary>
    internal const string LegacyFolderName = "TetherProxy";

    public static AppPaths CreateDefault() => CreateIn(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData, Environment.SpecialFolderOption.Create));

    /// <summary>
    /// Rutas bajo <paramref name="dataRoot"/>. Si solo existe la carpeta antigua, la renombra para conservar los ajustes
    /// y, sobre todo, la copia de la configuración de proxy que hay que restaurar tras un cierre inesperado.
    /// </summary>
    internal static AppPaths CreateIn(string dataRoot)
    {
        var root = Path.Combine(dataRoot, FolderName);
        MigrateLegacyFolder(Path.Combine(dataRoot, LegacyFolderName), root);
        return new AppPaths(
            Path.Combine(root, "settings.json"),
            Path.Combine(root, "proxy-recovery.json"),
            Path.Combine(root, "environment-recovery.json"));
    }

    private static void MigrateLegacyFolder(string legacyRoot, string root)
    {
        if (Directory.Exists(root) || !Directory.Exists(legacyRoot))
        {
            return;
        }

        try
        {
            Directory.Move(legacyRoot, root);
        }
        catch (IOException)
        {
            CopyFiles(legacyRoot, root);
        }
        catch (UnauthorizedAccessException)
        {
            CopyFiles(legacyRoot, root);
        }
    }

    /// <summary>Si no se puede mover (carpeta en uso), copia los archivos y deja la antigua intacta.</summary>
    private static void CopyFiles(string legacyRoot, string root)
    {
        Directory.CreateDirectory(root);
        foreach (var file in Directory.EnumerateFiles(legacyRoot))
        {
            File.Copy(file, Path.Combine(root, Path.GetFileName(file)), overwrite: false);
        }
    }
}
