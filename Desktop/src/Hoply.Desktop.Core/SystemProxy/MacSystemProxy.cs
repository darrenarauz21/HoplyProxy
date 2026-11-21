using Hoply.Desktop.Core.Support;

namespace Hoply.Desktop.Core.SystemProxy;

/// <summary>
/// Proxy automático de macOS con networksetup, en todos los servicios de red activos (Wi-Fi, Ethernet, USB…), para que
/// funcione sin importar por cuál salga la laptop.
/// </summary>
public sealed class MacSystemProxy : ISystemProxyConfigurator
{
    private const string Tool = "/usr/sbin/networksetup";
    private const string DisabledServicePrefix = "*";

    public string Platform => "macos";

    public bool IsSupported => File.Exists(Tool);

    public async Task<SystemProxySnapshot> CaptureAsync(CancellationToken cancellationToken)
    {
        var values = new Dictionary<string, string?>(StringComparer.Ordinal);
        foreach (var service in await ListServicesAsync(cancellationToken).ConfigureAwait(false))
        {
            var output = await CommandRunner.RunAsync(Tool, ["-getautoproxyurl", service], cancellationToken).ConfigureAwait(false);
            values[service] = ParseEnabledUrl(output);
        }
        return new SystemProxySnapshot(Platform, values);
    }

    public async Task ApplyAsync(string pacUrl, CancellationToken cancellationToken)
    {
        foreach (var service in await ListServicesAsync(cancellationToken).ConfigureAwait(false))
        {
            await CommandRunner.RunAsync(Tool, ["-setautoproxyurl", service, pacUrl], cancellationToken).ConfigureAwait(false);
        }
    }

    public async Task RestoreAsync(SystemProxySnapshot snapshot, CancellationToken cancellationToken)
    {
        var failures = new List<Exception>();
        foreach (var (service, previousUrl) in snapshot.Values)
        {
            string[] arguments = previousUrl is null
                ? ["-setautoproxystate", service, "off"]
                : ["-setautoproxyurl", service, previousUrl];
            try
            {
                await CommandRunner.RunAsync(Tool, arguments, cancellationToken).ConfigureAwait(false);
            }
            catch (SystemProxyException exception)
            {
                failures.Add(exception);
            }
        }
        if (failures.Count > 0)
        {
            throw new SystemProxyException("No se pudo restaurar el proxy de algunos servicios de red.", new AggregateException(failures));
        }
    }

    /// <summary>La primera línea es un aviso; los servicios desactivados empiezan con un asterisco.</summary>
    internal static IReadOnlyList<string> ParseServices(string output) => output
        .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
        .Skip(1)
        .Where(line => !line.StartsWith(DisabledServicePrefix, StringComparison.Ordinal))
        .ToList();

    /// <summary>La URL anterior si el proxy automático estaba activo; null si no.</summary>
    internal static string? ParseEnabledUrl(string output)
    {
        string? url = null;
        var enabled = false;
        foreach (var line in output.Split('\n', StringSplitOptions.TrimEntries))
        {
            if (line.StartsWith("URL:", StringComparison.Ordinal))
            {
                url = line["URL:".Length..].Trim();
            }
            else if (line.StartsWith("Enabled:", StringComparison.Ordinal))
            {
                enabled = line["Enabled:".Length..].Trim().Equals("Yes", StringComparison.OrdinalIgnoreCase);
            }
        }
        return enabled && !string.IsNullOrEmpty(url) && url != "(null)" ? url : null;
    }

    private static async Task<IReadOnlyList<string>> ListServicesAsync(CancellationToken cancellationToken)
    {
        var output = await CommandRunner.RunAsync(Tool, ["-listallnetworkservices"], cancellationToken).ConfigureAwait(false);
        return ParseServices(output);
    }
}
