using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Security;
using Microsoft.Win32;

namespace Hoply.Desktop.Core.SystemProxy;

/// <summary>
/// Proxy automático de Windows («Usar script de instalación»): el valor AutoConfigURL del usuario actual. Lo leen
/// Edge, Chrome y la mayoría de las apps. No requiere permisos de administrador.
/// </summary>
[SupportedOSPlatform("windows")]
public sealed class WindowsSystemProxy : ISystemProxyConfigurator
{
    private const string InternetSettingsKey = @"Software\Microsoft\Windows\CurrentVersion\Internet Settings";
    private const string AutoConfigUrlValue = "AutoConfigURL";
    private const int SettingsChangedOption = 39;
    private const int RefreshOption = 37;

    public string Platform => "windows";

    public bool IsSupported => true;

    public Task<SystemProxySnapshot> CaptureAsync(CancellationToken cancellationToken)
    {
        var previous = Guard(() =>
        {
            using var key = Registry.CurrentUser.OpenSubKey(InternetSettingsKey);
            return key?.GetValue(AutoConfigUrlValue) as string;
        });
        var values = new Dictionary<string, string?>(StringComparer.Ordinal) { [AutoConfigUrlValue] = previous };
        return Task.FromResult(new SystemProxySnapshot(Platform, values));
    }

    public Task ApplyAsync(string pacUrl, CancellationToken cancellationToken)
    {
        Write(pacUrl);
        return Task.CompletedTask;
    }

    public Task RestoreAsync(SystemProxySnapshot snapshot, CancellationToken cancellationToken)
    {
        Write(snapshot.Values.GetValueOrDefault(AutoConfigUrlValue));
        return Task.CompletedTask;
    }

    private static void Write(string? pacUrl)
    {
        Guard(() =>
        {
            using var key = Registry.CurrentUser.CreateSubKey(InternetSettingsKey, writable: true);
            if (pacUrl is null)
            {
                key.DeleteValue(AutoConfigUrlValue, throwOnMissingValue: false);
            }
            else
            {
                key.SetValue(AutoConfigUrlValue, pacUrl, RegistryValueKind.String);
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
