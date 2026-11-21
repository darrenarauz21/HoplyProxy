using Hoply.Desktop.Core.Support;

namespace Hoply.Desktop.Core.SystemProxy;

/// <summary>
/// Proxy automático de los escritorios basados en GNOME (GNOME, Cinnamon, Budgie, Unity) mediante gsettings. Los valores
/// se guardan y restauran en el formato de GVariant que devuelve «gsettings get».
/// </summary>
public sealed class GnomeSystemProxy : ISystemProxyConfigurator
{
    private const string Tool = "gsettings";
    private const string Schema = "org.gnome.system.proxy";
    private const string ModeKey = "mode";
    private const string UrlKey = "autoconfig-url";

    public string Platform => "gnome";

    public bool IsSupported => CommandRunner.IsOnPath(Tool);

    public async Task<SystemProxySnapshot> CaptureAsync(CancellationToken cancellationToken)
    {
        var values = new Dictionary<string, string?>(StringComparer.Ordinal)
        {
            [ModeKey] = await GetAsync(ModeKey, cancellationToken).ConfigureAwait(false),
            [UrlKey] = await GetAsync(UrlKey, cancellationToken).ConfigureAwait(false),
        };
        return new SystemProxySnapshot(Platform, values);
    }

    public async Task ApplyAsync(string pacUrl, CancellationToken cancellationToken)
    {
        await SetAsync(UrlKey, Quote(pacUrl), cancellationToken).ConfigureAwait(false);
        await SetAsync(ModeKey, Quote("auto"), cancellationToken).ConfigureAwait(false);
    }

    public async Task RestoreAsync(SystemProxySnapshot snapshot, CancellationToken cancellationToken)
    {
        await SetAsync(UrlKey, snapshot.Values.GetValueOrDefault(UrlKey) ?? Quote(string.Empty), cancellationToken).ConfigureAwait(false);
        await SetAsync(ModeKey, snapshot.Values.GetValueOrDefault(ModeKey) ?? Quote("none"), cancellationToken).ConfigureAwait(false);
    }

    /// <summary>Cadena de GVariant entre comillas simples, escapando las que contenga.</summary>
    internal static string Quote(string value) => $"'{value.Replace("\\", "\\\\", StringComparison.Ordinal).Replace("'", "\\'", StringComparison.Ordinal)}'";

    private static async Task<string> GetAsync(string key, CancellationToken cancellationToken)
    {
        var output = await CommandRunner.RunAsync(Tool, ["get", Schema, key], cancellationToken).ConfigureAwait(false);
        return output.Trim();
    }

    private static Task<string> SetAsync(string key, string value, CancellationToken cancellationToken) =>
        CommandRunner.RunAsync(Tool, ["set", Schema, key, value], cancellationToken);
}
