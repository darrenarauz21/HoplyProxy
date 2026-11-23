using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Security;
using Microsoft.Win32;

namespace Hoply.Desktop.Core.SystemProxy;

/// <summary>
/// Variables de entorno de proxy del usuario. Las leen Node.js (Claude Code, Codex, npm), git, curl, Python y la mayoría
/// de las herramientas de terminal, que ignoran el proxy automático del sistema.
/// </summary>
public interface IEnvironmentProxyConfigurator
{
    string Platform { get; }

    bool IsSupported { get; }

    Task<SystemProxySnapshot> CaptureAsync(CancellationToken cancellationToken);

    Task ApplyAsync(string httpProxyUrl, CancellationToken cancellationToken);

    Task RestoreAsync(SystemProxySnapshot snapshot, CancellationToken cancellationToken);
}

/// <summary>Qué variables se definen y con qué valor.</summary>
public static class EnvironmentProxyVariables
{
    public const string HttpProxy = "HTTP_PROXY";
    public const string HttpsProxy = "HTTPS_PROXY";
    public const string NoProxy = "NO_PROXY";

    /// <summary>Node.js 24 solo usa HTTP_PROXY en fetch con esta variable; las versiones anteriores la ignoran.</summary>
    public const string NodeUseEnvProxy = "NODE_USE_ENV_PROXY";

    /// <summary>Direcciones locales que nunca pasan por el iPhone.</summary>
    public const string LocalAddresses = "localhost,127.0.0.1,::1";

    public static IReadOnlyList<string> Names { get; } = [HttpProxy, HttpsProxy, NoProxy, NodeUseEnvProxy];

    public static IReadOnlyDictionary<string, string> For(string httpProxyUrl) => new Dictionary<string, string>(StringComparer.Ordinal)
    {
        [HttpProxy] = httpProxyUrl,
        [HttpsProxy] = httpProxyUrl,
        [NoProxy] = LocalAddresses,
        [NodeUseEnvProxy] = "1",
    };
}

public static class EnvironmentProxyConfiguratorFactory
{
    public static IEnvironmentProxyConfigurator CreateForCurrentPlatform() =>
        OperatingSystem.IsWindows() ? new WindowsEnvironmentProxy() : new UnsupportedEnvironmentProxy();
}

/// <summary>Sistemas donde la app no sabe definir variables para todo el usuario: se usa «Copiar para la terminal».</summary>
public sealed class UnsupportedEnvironmentProxy : IEnvironmentProxyConfigurator
{
    public string Platform => "unsupported-environment";

    public bool IsSupported => false;

    public Task<SystemProxySnapshot> CaptureAsync(CancellationToken cancellationToken) => throw new NotSupportedException();

    public Task ApplyAsync(string httpProxyUrl, CancellationToken cancellationToken) => throw new NotSupportedException();

    public Task RestoreAsync(SystemProxySnapshot snapshot, CancellationToken cancellationToken) => throw new NotSupportedException();
}

/// <summary>
/// Variables del usuario en Windows (HKCU\Environment), las mismas que se editan en «Variables de entorno». No requiere
/// permisos de administrador. Solo las ven los programas que se abren después: las apps y terminales abiertas deben
/// reiniciarse.
/// </summary>
[SupportedOSPlatform("windows")]
public sealed class WindowsEnvironmentProxy : IEnvironmentProxyConfigurator
{
    private const string EnvironmentKey = "Environment";

    public string Platform => "windows-environment";

    public bool IsSupported => true;

    public Task<SystemProxySnapshot> CaptureAsync(CancellationToken cancellationToken)
    {
        var values = Guard(() =>
        {
            using var key = Registry.CurrentUser.OpenSubKey(EnvironmentKey);
            var previous = new Dictionary<string, string?>(StringComparer.Ordinal);
            foreach (var name in EnvironmentProxyVariables.Names)
            {
                previous[name] = key?.GetValue(name, null, RegistryValueOptions.DoNotExpandEnvironmentNames) as string;
            }
            return previous;
        });
        return Task.FromResult(new SystemProxySnapshot(Platform, values));
    }

    public Task ApplyAsync(string httpProxyUrl, CancellationToken cancellationToken)
    {
        Write(EnvironmentProxyVariables.For(httpProxyUrl).ToDictionary(pair => pair.Key, pair => (string?)pair.Value));
        return Task.CompletedTask;
    }

    public Task RestoreAsync(SystemProxySnapshot snapshot, CancellationToken cancellationToken)
    {
        Write(EnvironmentProxyVariables.Names.ToDictionary(name => name, name => snapshot.Values.GetValueOrDefault(name)));
        return Task.CompletedTask;
    }

    private static void Write(IReadOnlyDictionary<string, string?> values)
    {
        Guard(() =>
        {
            using var key = Registry.CurrentUser.CreateSubKey(EnvironmentKey, writable: true);
            foreach (var (name, value) in values)
            {
                if (value is null)
                {
                    key.DeleteValue(name, throwOnMissingValue: false);
                }
                else
                {
                    var kind = value.Contains('%', StringComparison.Ordinal) ? RegistryValueKind.ExpandString : RegistryValueKind.String;
                    key.SetValue(name, value, kind);
                }
            }
            return true;
        });
        NativeMethods.BroadcastEnvironmentChange();
    }

    private static T Guard<T>(Func<T> action)
    {
        try
        {
            return action();
        }
        catch (Exception exception) when (exception is UnauthorizedAccessException or SecurityException or IOException)
        {
            throw new SystemProxyException("No se pudieron cambiar las variables de entorno del usuario.", exception);
        }
    }

    private static class NativeMethods
    {
        private static readonly IntPtr BroadcastHandle = new(0xffff);
        private const uint SettingChangeMessage = 0x001A;
        private const uint AbortIfHung = 0x0002;
        private const uint TimeoutMilliseconds = 2000;

        /// <summary>Avisa al Explorador para que los programas que se abran después reciban las variables nuevas.</summary>
        public static void BroadcastEnvironmentChange() =>
            SendMessageTimeout(BroadcastHandle, SettingChangeMessage, IntPtr.Zero, "Environment", AbortIfHung, TimeoutMilliseconds, out _);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr SendMessageTimeout(
            IntPtr window, uint message, IntPtr wParam, string lParam, uint flags, uint timeout, out IntPtr result);
    }
}
