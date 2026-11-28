using System.Net;
using System.Runtime.Versioning;
using Hoply.Desktop.Core.Connection;
using Hoply.Desktop.Core.Storage;
using Hoply.Desktop.Core.SystemProxy;
using Hoply.Desktop.Core.Usbmux;
using Hoply.Desktop.Core.Verification;
using Microsoft.Win32;

namespace Hoply.Desktop.Tests;

/// <summary>
/// Proxy automático y manual de Windows. Cada prueba usa una clave temporal de HKCU en lugar de la configuración real.
/// </summary>
[SupportedOSPlatform("windows")]
public sealed class WindowsSystemProxyTests : IDisposable
{
    private const string PacUrl = "http://127.0.0.1:1180/proxy.pac";
    private const string TestsKeyPath = @"Software\Hoply.Tests";

    private readonly string _keyPath = $@"{TestsKeyPath}\{Guid.NewGuid():N}";
    private readonly string _folder = Path.Combine(Path.GetTempPath(), "hoply-tests", Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        Registry.CurrentUser.DeleteSubKeyTree(_keyPath, throwOnMissingSubKey: false);
        using (var parent = Registry.CurrentUser.OpenSubKey(TestsKeyPath))
        {
            if (parent is { SubKeyCount: 0, ValueCount: 0 })
            {
                parent.Close();
                Registry.CurrentUser.DeleteSubKey(TestsKeyPath, throwOnMissingSubKey: false);
            }
        }
        if (Directory.Exists(_folder))
        {
            Directory.Delete(_folder, recursive: true);
        }
    }

    [WindowsFact]
    public async Task AppliesAutomaticAndManualProxy()
    {
        var proxy = new WindowsSystemProxy(_keyPath);

        await proxy.ApplyAsync(PacUrl, CancellationToken.None);

        using var key = OpenKey();
        Assert.Equal(PacUrl, key.GetValue(WindowsSystemProxy.AutoConfigUrlValue));
        Assert.Equal(1, key.GetValue(WindowsSystemProxy.ProxyEnableValue));
        Assert.Equal(RegistryValueKind.DWord, key.GetValueKind(WindowsSystemProxy.ProxyEnableValue));
        Assert.Equal("127.0.0.1:1180", key.GetValue(WindowsSystemProxy.ProxyServerValue));
        Assert.Equal("<local>;localhost;127.0.0.1", key.GetValue(WindowsSystemProxy.ProxyOverrideValue));
    }

    [WindowsFact]
    public async Task CapturesAndRestoresTheFourPreviousValues()
    {
        WritePrevious();
        var proxy = new WindowsSystemProxy(_keyPath);

        var snapshot = await proxy.CaptureAsync(CancellationToken.None);
        await proxy.ApplyAsync(PacUrl, CancellationToken.None);
        await proxy.RestoreAsync(snapshot, CancellationToken.None);

        Assert.Equal("http://empresa/proxy.pac", snapshot.Values[WindowsSystemProxy.AutoConfigUrlValue]);
        Assert.Equal("0", snapshot.Values[WindowsSystemProxy.ProxyEnableValue]);
        AssertPreviousValues();
    }

    [WindowsFact]
    public async Task DeletesValuesThatDidNotExistBefore()
    {
        var proxy = new WindowsSystemProxy(_keyPath);

        var snapshot = await proxy.CaptureAsync(CancellationToken.None);
        await proxy.ApplyAsync(PacUrl, CancellationToken.None);
        await proxy.RestoreAsync(snapshot, CancellationToken.None);

        Assert.All(snapshot.Values.Values, Assert.Null);
        using var key = OpenKey();
        Assert.Empty(key.GetValueNames());
    }

    [WindowsFact]
    public async Task RestoringAnOldSnapshotLeavesManualProxyAlone()
    {
        using (var key = Registry.CurrentUser.CreateSubKey(_keyPath))
        {
            key.SetValue(WindowsSystemProxy.ProxyServerValue, "proxy.empresa:8080");
            key.SetValue(WindowsSystemProxy.AutoConfigUrlValue, PacUrl);
        }
        var oldSnapshot = new SystemProxySnapshot("windows", new Dictionary<string, string?>
        {
            [WindowsSystemProxy.AutoConfigUrlValue] = null,
        });

        await new WindowsSystemProxy(_keyPath).RestoreAsync(oldSnapshot, CancellationToken.None);

        using var restored = OpenKey();
        Assert.Null(restored.GetValue(WindowsSystemProxy.AutoConfigUrlValue));
        Assert.Equal("proxy.empresa:8080", restored.GetValue(WindowsSystemProxy.ProxyServerValue));
    }

    [WindowsFact]
    public async Task RecoversAfterTheAppClosedWithoutDisconnecting()
    {
        WritePrevious();
        var recoveryFile = Path.Combine(_folder, "recovery.json");
        var environmentRecoveryFile = Path.Combine(_folder, "environment-recovery.json");
        var options = ConnectionOptions.Create(ConnectionMode.WiFi, "192.168.1.20", 1180, configureSystemProxy: true);

        // Primera ejecución: conecta y la app se cierra de golpe, sin desconectar.
        var crashed = CreateConnection(recoveryFile, environmentRecoveryFile);
        await crashed.ConnectAsync(options, CancellationToken.None);
        using (var key = OpenKey())
        {
            Assert.Equal("192.168.1.20:1180", key.GetValue(WindowsSystemProxy.ProxyServerValue));
            Assert.Equal(1, key.GetValue(WindowsSystemProxy.ProxyEnableValue));
        }
        Assert.True(File.Exists(recoveryFile));

        // Siguiente apertura: restaura desde el archivo de recuperación.
        var reopened = CreateConnection(recoveryFile, environmentRecoveryFile);
        var restored = await reopened.RecoverPendingSystemProxyAsync(CancellationToken.None);

        Assert.True(restored);
        Assert.False(File.Exists(recoveryFile));
        AssertPreviousValues();
    }

    private PhoneConnection CreateConnection(string recoveryFile, string environmentRecoveryFile) => new(
        new NoUsbmux(),
        new WindowsSystemProxy(_keyPath),
        new ProxyRecoveryStore(recoveryFile),
        new NoVerifier(),
        new UnsupportedEnvironmentProxy(),
        new ProxyRecoveryStore(environmentRecoveryFile),
        new AlwaysReachableProbe());

    private void WritePrevious()
    {
        using var key = Registry.CurrentUser.CreateSubKey(_keyPath);
        key.SetValue(WindowsSystemProxy.AutoConfigUrlValue, "http://empresa/proxy.pac", RegistryValueKind.String);
        key.SetValue(WindowsSystemProxy.ProxyEnableValue, 0, RegistryValueKind.DWord);
        key.SetValue(WindowsSystemProxy.ProxyServerValue, "proxy.empresa:8080", RegistryValueKind.String);
        key.SetValue(WindowsSystemProxy.ProxyOverrideValue, "*.empresa.local", RegistryValueKind.String);
    }

    private void AssertPreviousValues()
    {
        using var key = OpenKey();
        Assert.Equal("http://empresa/proxy.pac", key.GetValue(WindowsSystemProxy.AutoConfigUrlValue));
        Assert.Equal(0, key.GetValue(WindowsSystemProxy.ProxyEnableValue));
        Assert.Equal(RegistryValueKind.DWord, key.GetValueKind(WindowsSystemProxy.ProxyEnableValue));
        Assert.Equal("proxy.empresa:8080", key.GetValue(WindowsSystemProxy.ProxyServerValue));
        Assert.Equal("*.empresa.local", key.GetValue(WindowsSystemProxy.ProxyOverrideValue));
    }

    private RegistryKey OpenKey() => Registry.CurrentUser.OpenSubKey(_keyPath)
        ?? throw new InvalidOperationException("La clave de prueba no existe.");

    private sealed class NoUsbmux : IUsbmuxClient
    {
        public Task<IReadOnlyList<UsbDevice>> ListDevicesAsync(CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<UsbDevice>>([]);

        public Task<Stream> ConnectAsync(int deviceId, ushort devicePort, CancellationToken cancellationToken) =>
            throw new NotSupportedException();
    }

    private sealed class NoVerifier : IConnectionVerifier
    {
        public Task<IPAddress?> TryGetPublicAddressAsync(string proxyHost, ushort port, CancellationToken cancellationToken) =>
            Task.FromResult<IPAddress?>(null);
    }

    private sealed class AlwaysReachableProbe : IProxyProbe
    {
        public Task<bool> IsReachableAsync(string host, ushort port, CancellationToken cancellationToken) => Task.FromResult(true);
    }
}

/// <summary>Prueba que solo se ejecuta en Windows; en los demás sistemas aparece como omitida.</summary>
public sealed class WindowsFactAttribute : FactAttribute
{
    public WindowsFactAttribute()
    {
        if (!OperatingSystem.IsWindows())
        {
            Skip = "Solo en Windows.";
        }
    }
}
