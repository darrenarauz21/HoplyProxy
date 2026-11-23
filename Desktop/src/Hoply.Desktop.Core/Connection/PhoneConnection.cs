using System.Net;
using System.Net.Sockets;
using Hoply.Desktop.Core.Storage;
using Hoply.Desktop.Core.SystemProxy;
using Hoply.Desktop.Core.Usbmux;
using Hoply.Desktop.Core.Verification;

namespace Hoply.Desktop.Core.Connection;

/// <summary>
/// Orquesta una conexión: reenvío USB si hace falta, proxy del sistema, variables de entorno, verificación y vigilancia
/// de la conexión. Al desconectar deja la laptop como estaba. No es seguro para hilos: se usa desde la interfaz, una
/// operación a la vez.
/// </summary>
public sealed class PhoneConnection : IAsyncDisposable
{
    private readonly IUsbmuxClient _usbmux;
    private readonly ISystemProxyConfigurator _systemProxy;
    private readonly ProxyRecoveryStore _recovery;
    private readonly IConnectionVerifier _verifier;
    private readonly IEnvironmentProxyConfigurator _environmentProxy;
    private readonly ProxyRecoveryStore _environmentRecovery;
    private readonly IProxyProbe _probe;
    private UsbPortForwarder? _forwarder;
    private SystemProxySnapshot? _appliedSnapshot;
    private SystemProxySnapshot? _appliedEnvironmentSnapshot;
    private ConnectionHealthMonitor? _monitor;

    public PhoneConnection(
        IUsbmuxClient usbmux,
        ISystemProxyConfigurator systemProxy,
        ProxyRecoveryStore recovery,
        IConnectionVerifier verifier,
        IEnvironmentProxyConfigurator environmentProxy,
        ProxyRecoveryStore environmentRecovery,
        IProxyProbe probe)
    {
        _usbmux = usbmux;
        _systemProxy = systemProxy;
        _recovery = recovery;
        _verifier = verifier;
        _environmentProxy = environmentProxy;
        _environmentRecovery = environmentRecovery;
        _probe = probe;
    }

    /// <summary>Intervalo entre comprobaciones mientras el iPhone responde.</summary>
    public static TimeSpan HealthyCheckInterval { get; } = TimeSpan.FromSeconds(5);

    /// <summary>Intervalo de reintento mientras el iPhone no responde.</summary>
    public static TimeSpan UnreachableCheckInterval { get; } = TimeSpan.FromSeconds(2);

    public ConnectionState State { get; private set; } = ConnectionState.Disconnected;

    public ConnectionOptions? ActiveOptions { get; private set; }

    public bool IsSystemProxySupported => _systemProxy.IsSupported;

    public bool IsEnvironmentProxySupported => _environmentProxy.IsSupported;

    /// <summary>Estado del proxy del iPhone mientras la conexión está activa.</summary>
    public ConnectionHealth Health => _monitor?.Health ?? ConnectionHealth.Healthy;

    /// <summary>El iPhone dejó de responder o volvió. Puede invocarse fuera del hilo de la interfaz.</summary>
    public event EventHandler<ConnectionHealth>? HealthChanged;

    /// <summary>Puede invocarse fuera del hilo de la interfaz.</summary>
    public event EventHandler? StateChanged;

    /// <summary>Una conexión reenviada por USB no llegó al iPhone. Puede invocarse fuera del hilo de la interfaz.</summary>
    public event EventHandler<UsbmuxException>? ForwardingFailed;

    /// <summary>Restaura un proxy del sistema que quedó cambiado porque la app se cerró sin desconectar.</summary>
    public async Task<bool> RecoverPendingSystemProxyAsync(CancellationToken cancellationToken)
    {
        var restored = false;
        var snapshot = _recovery.Load();
        if (snapshot is not null)
        {
            if (snapshot.Platform == _systemProxy.Platform && _systemProxy.IsSupported)
            {
                await _systemProxy.RestoreAsync(snapshot, cancellationToken).ConfigureAwait(false);
                restored = true;
            }
            _recovery.Clear();
        }

        var environmentSnapshot = _environmentRecovery.Load();
        if (environmentSnapshot is not null)
        {
            if (environmentSnapshot.Platform == _environmentProxy.Platform && _environmentProxy.IsSupported)
            {
                await _environmentProxy.RestoreAsync(environmentSnapshot, cancellationToken).ConfigureAwait(false);
                restored = true;
            }
            _environmentRecovery.Clear();
        }
        return restored;
    }

    public async Task<ConnectionReport> ConnectAsync(ConnectionOptions options, CancellationToken cancellationToken)
    {
        if (State != ConnectionState.Disconnected)
        {
            throw new InvalidOperationException("Ya hay una conexión en curso.");
        }
        if (ConnectionOptionsValidator.Validate(options).Count > 0)
        {
            throw new ConnectionException(ConnectionFailure.InvalidOptions);
        }

        SetState(ConnectionState.Connecting);
        try
        {
            if (options.Mode == ConnectionMode.Usb)
            {
                await StartForwardingAsync(options.Port, cancellationToken).ConfigureAwait(false);
            }
            if (options.ConfigureSystemProxy && _systemProxy.IsSupported)
            {
                await ApplySystemProxyAsync(options.PacUrl, cancellationToken).ConfigureAwait(false);
            }
            if (options.ConfigureEnvironmentProxy && _environmentProxy.IsSupported)
            {
                await ApplyEnvironmentProxyAsync(options.HttpProxyUrl, cancellationToken).ConfigureAwait(false);
            }

            var publicAddress = await _verifier.TryGetPublicAddressAsync(options.Host, options.Port, cancellationToken).ConfigureAwait(false);
            ActiveOptions = options;
            StartMonitor(options);
            SetState(ConnectionState.Connected);
            return new ConnectionReport(publicAddress, _appliedSnapshot is not null, _appliedEnvironmentSnapshot is not null);
        }
        catch
        {
            await TearDownAsync().ConfigureAwait(false);
            SetState(ConnectionState.Disconnected);
            throw;
        }
    }

    /// <summary>Vuelve a pedir la IP pública con la conexión activa.</summary>
    public Task<IPAddress?> VerifyAsync(CancellationToken cancellationToken) => ActiveOptions is { } options
        ? _verifier.TryGetPublicAddressAsync(options.Host, options.Port, cancellationToken)
        : Task.FromResult<IPAddress?>(null);

    /// <summary>
    /// Tras volver a responder el iPhone, vuelve a aplicar el proxy automático para que el sistema descargue de nuevo el
    /// PAC (mientras no respondía, Windows y los navegadores pudieron pasar a conexión directa) y verifica la IP pública.
    /// </summary>
    public async Task<IPAddress?> RefreshAfterRecoveryAsync(CancellationToken cancellationToken)
    {
        if (ActiveOptions is not { } options || State != ConnectionState.Connected)
        {
            return null;
        }
        if (_appliedSnapshot is not null)
        {
            try
            {
                await _systemProxy.ApplyAsync(options.PacUrl, cancellationToken).ConfigureAwait(false);
            }
            catch (SystemProxyException)
            {
                // La configuración sigue puesta; solo no se pudo forzar la relectura.
            }
        }
        return await _verifier.TryGetPublicAddressAsync(options.Host, options.Port, cancellationToken).ConfigureAwait(false);
    }

    /// <summary>Restaura el proxy y detiene el reenvío. Si restaurar falla, se reintenta al abrir la app.</summary>
    public async Task<bool> DisconnectAsync()
    {
        if (State is ConnectionState.Disconnected or ConnectionState.Disconnecting)
        {
            return true;
        }
        SetState(ConnectionState.Disconnecting);
        var restored = await TearDownAsync().ConfigureAwait(false);
        SetState(ConnectionState.Disconnected);
        return restored;
    }

    public async ValueTask DisposeAsync() => await DisconnectAsync().ConfigureAwait(false);

    private async Task StartForwardingAsync(ushort port, CancellationToken cancellationToken)
    {
        IReadOnlyList<UsbDevice> devices;
        try
        {
            devices = await _usbmux.ListDevicesAsync(cancellationToken).ConfigureAwait(false);
        }
        catch (UsbmuxException exception)
        {
            throw new ConnectionException(ConnectionFailure.UsbServiceUnavailable, exception);
        }
        if (!devices.Any(device => device.IsUsb))
        {
            throw new ConnectionException(ConnectionFailure.DeviceNotFound);
        }

        var forwarder = new UsbPortForwarder(_usbmux, port, port);
        forwarder.SessionFailed += OnSessionFailed;
        _forwarder = forwarder;
        try
        {
            forwarder.Start();
        }
        catch (SocketException exception)
        {
            throw new ConnectionException(ConnectionFailure.PortInUse, exception);
        }
    }

    private async Task ApplySystemProxyAsync(string pacUrl, CancellationToken cancellationToken)
    {
        try
        {
            var snapshot = await _systemProxy.CaptureAsync(cancellationToken).ConfigureAwait(false);
            _recovery.Save(snapshot);
            _appliedSnapshot = snapshot;
            await _systemProxy.ApplyAsync(pacUrl, cancellationToken).ConfigureAwait(false);
        }
        catch (SystemProxyException exception)
        {
            throw new ConnectionException(ConnectionFailure.SystemProxyFailed, exception);
        }
    }

    private async Task ApplyEnvironmentProxyAsync(string httpProxyUrl, CancellationToken cancellationToken)
    {
        try
        {
            var snapshot = await _environmentProxy.CaptureAsync(cancellationToken).ConfigureAwait(false);
            _environmentRecovery.Save(snapshot);
            _appliedEnvironmentSnapshot = snapshot;
            await _environmentProxy.ApplyAsync(httpProxyUrl, cancellationToken).ConfigureAwait(false);
        }
        catch (SystemProxyException exception)
        {
            throw new ConnectionException(ConnectionFailure.EnvironmentProxyFailed, exception);
        }
    }

    private void StartMonitor(ConnectionOptions options)
    {
        var monitor = new ConnectionHealthMonitor(_probe, options.Host, options.Port, HealthyCheckInterval, UnreachableCheckInterval);
        monitor.HealthChanged += OnHealthChanged;
        _monitor = monitor;
        monitor.Start();
    }

    private async Task<bool> TearDownAsync()
    {
        if (_monitor is { } monitor)
        {
            monitor.HealthChanged -= OnHealthChanged;
            await monitor.DisposeAsync().ConfigureAwait(false);
            _monitor = null;
        }

        var restored = true;
        if (_appliedSnapshot is { } snapshot)
        {
            try
            {
                await _systemProxy.RestoreAsync(snapshot, CancellationToken.None).ConfigureAwait(false);
                _recovery.Clear();
            }
            catch (SystemProxyException)
            {
                // El archivo de recuperación se conserva y se reintenta al abrir la app.
                restored = false;
            }
            _appliedSnapshot = null;
        }

        if (_appliedEnvironmentSnapshot is { } environmentSnapshot)
        {
            try
            {
                await _environmentProxy.RestoreAsync(environmentSnapshot, CancellationToken.None).ConfigureAwait(false);
                _environmentRecovery.Clear();
            }
            catch (SystemProxyException)
            {
                restored = false;
            }
            _appliedEnvironmentSnapshot = null;
        }

        if (_forwarder is { } forwarder)
        {
            forwarder.SessionFailed -= OnSessionFailed;
            await forwarder.DisposeAsync().ConfigureAwait(false);
            _forwarder = null;
        }
        ActiveOptions = null;
        return restored;
    }

    private void OnSessionFailed(object? sender, UsbmuxException exception)
    {
        ForwardingFailed?.Invoke(this, exception);
        // Un fallo del cable se confirma enseguida en lugar de esperar a la siguiente comprobación.
        _monitor?.CheckNow();
    }

    private void OnHealthChanged(object? sender, ConnectionHealth health) => HealthChanged?.Invoke(this, health);

    private void SetState(ConnectionState state)
    {
        State = state;
        StateChanged?.Invoke(this, EventArgs.Empty);
    }
}
