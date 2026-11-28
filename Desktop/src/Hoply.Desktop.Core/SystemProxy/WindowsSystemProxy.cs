using System.Globalization;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Security;
using Microsoft.Win32;

namespace Hoply.Desktop.Core.SystemProxy;

/// <summary>
/// Proxy de Windows del usuario actual, en dos formas a la vez. El automático («Usar script de instalación»,
/// AutoConfigURL) lo leen Edge, Chrome y la mayoría de las apps. El manual (ProxyEnable, ProxyServer y ProxyOverride) lo
/// leen además muchas apps .NET, WinHTTP y de consola que ignoran el PAC. No requiere permisos de administrador.
/// </summary>
[SupportedOSPlatform("windows")]
public sealed class WindowsSystemProxy : ISystemProxyConfigurator
{
    internal const string InternetSettingsKey = @"Software\Microsoft\Windows\CurrentVersion\Internet Settings";
    internal const string AutoConfigUrlValue = "AutoConfigURL";
    internal const string ProxyEnableValue = "ProxyEnable";
    internal const string ProxyServerValue = "ProxyServer";
    internal const string ProxyOverrideValue = "ProxyOverride";

    /// <summary>Direcciones que no pasan por el proxy manual: nombres sin punto y la propia laptop.</summary>
    internal const string LocalAddresses = "<local>;localhost;127.0.0.1";

    private const int SettingsChangedOption = 39;
    private const int RefreshOption = 37;

    private static readonly string[] ManagedValues = [AutoConfigUrlValue, ProxyEnableValue, ProxyServerValue, ProxyOverrideValue];

    private readonly string _keyPath;

    public WindowsSystemProxy()
        : this(InternetSettingsKey)
    {
    }

    /// <summary>Para las pruebas: trabaja sobre otra clave de HKCU en lugar de la configuración real.</summary>
    internal WindowsSystemProxy(string keyPath)
    {
        _keyPath = keyPath;
    }

    public string Platform => "windows";

    public bool IsSupported => true;

    public Task<SystemProxySnapshot> CaptureAsync(CancellationToken cancellationToken)
    {
        var values = Guard(() =>
        {
            using var key = Registry.CurrentUser.OpenSubKey(_keyPath);
            return ManagedValues.ToDictionary(name => name, name => ReadValue(key, name), StringComparer.Ordinal);
        });
        return Task.FromResult(new SystemProxySnapshot(Platform, values));
    }

    public Task ApplyAsync(string pacUrl, CancellationToken cancellationToken)
    {
        if (!Uri.TryCreate(pacUrl, UriKind.Absolute, out var uri))
        {
            throw new SystemProxyException("La dirección del proxy automático no es válida.");
        }
        Write(new Dictionary<string, string?>(StringComparer.Ordinal)
        {
            [AutoConfigUrlValue] = pacUrl,
            [ProxyServerValue] = $"{uri.Host}:{uri.Port.ToString(CultureInfo.InvariantCulture)}",
            [ProxyOverrideValue] = LocalAddresses,
            [ProxyEnableValue] = "1",
        });
        return Task.CompletedTask;
    }

    /// <summary>
    /// Deja cada valor como estaba: lo escribe o, si no existía, lo borra. Las capturas de versiones anteriores solo
    /// traen AutoConfigURL; los valores que no aparecen en la captura no se tocan.
    /// </summary>
    public Task RestoreAsync(SystemProxySnapshot snapshot, CancellationToken cancellationToken)
    {
        var values = ManagedValues
            .Where(snapshot.Values.ContainsKey)
            .ToDictionary(name => name, name => snapshot.Values[name], StringComparer.Ordinal);
        Write(values);
        return Task.CompletedTask;
    }

    private static string? ReadValue(RegistryKey? key, string name) => key?.GetValue(name) switch
    {
        null => null,
        int number => number.ToString(CultureInfo.InvariantCulture),
        var other => other.ToString(),
    };

    private void Write(IReadOnlyDictionary<string, string?> values)
    {
        Guard(() =>
        {
            using var key = Registry.CurrentUser.CreateSubKey(_keyPath, writable: true);
            foreach (var (name, value) in values)
            {
                if (value is null)
                {
                    key.DeleteValue(name, throwOnMissingValue: false);
                }
                else if (name == ProxyEnableValue && int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var number))
                {
                    key.SetValue(name, number, RegistryValueKind.DWord);
                }
                else
                {
                    key.SetValue(name, value, RegistryValueKind.String);
                }
            }
            return true;
        });
        // Avisa a las apps abiertas para que no esperen a releer la configuración.
        NativeMethods.InternetSetOption(IntPtr.Zero, SettingsChangedOption, IntPtr.Zero, 0);
        NativeMethods.InternetSetOption(IntPtr.Zero, RefreshOption, IntPtr.Zero, 0);
    }

    private static T Guard<T>(Func<T> action)
    {
        try
        {
            return action();
        }
        catch (Exception exception) when (exception is UnauthorizedAccessException or SecurityException or IOException)
        {
            throw new SystemProxyException("No se pudo cambiar la configuración de proxy de Windows.", exception);
        }
    }

    private static class NativeMethods
    {
        [DllImport("wininet.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool InternetSetOption(IntPtr internet, int option, IntPtr buffer, int bufferLength);
    }
}
