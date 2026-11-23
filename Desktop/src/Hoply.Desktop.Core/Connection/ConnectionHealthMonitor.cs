using System.Net;
using System.Net.NetworkInformation;

namespace Hoply.Desktop.Core.Connection;

public enum ConnectionHealth
{
    /// <summary>El proxy del iPhone responde.</summary>
    Healthy,

    /// <summary>Varias comprobaciones seguidas sin respuesta: se sigue intentando hasta que vuelva.</summary>
    Unreachable,
}

/// <summary>Comprueba si el proxy del iPhone responde, sin salir a internet.</summary>
public interface IProxyProbe
{
    Task<bool> IsReachableAsync(string host, ushort port, CancellationToken cancellationToken);
}

/// <summary>
/// Pide el archivo PAC directamente al iPhone. Recorre el mismo camino que el tráfico (cable o Wi-Fi hasta la app), pero
/// no gasta datos móviles ni pide credenciales.
/// </summary>
public sealed class PacProxyProbe : IProxyProbe, IDisposable
{
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(4);
    private const int MaxResponseBytes = 16 * 1024;

    private readonly HttpClient _client = new(new SocketsHttpHandler
    {
        UseProxy = false,
        PooledConnectionLifetime = TimeSpan.Zero,
        ConnectTimeout = Timeout,
    })
    {
        Timeout = Timeout,
        MaxResponseContentBufferSize = MaxResponseBytes,
    };

    public async Task<bool> IsReachableAsync(string host, ushort port, CancellationToken cancellationToken)
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, $"http://{host}:{port}/proxy.pac");
            request.Headers.ConnectionClose = true;
            using var response = await _client.SendAsync(request, cancellationToken).ConfigureAwait(false);
            return response.StatusCode == HttpStatusCode.OK;
        }
        catch (HttpRequestException)
        {
            return false;
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return false;
        }
    }

    public void Dispose() => _client.Dispose();
}

/// <summary>
/// Vigila una conexión activa: comprueba el proxy cada pocos segundos, avisa cuando deja de responder y cuando vuelve.
/// Comprueba de inmediato si cambia la red de la laptop (por ejemplo, al despertar de la suspensión).
/// </summary>
public sealed class ConnectionHealthMonitor : IAsyncDisposable
{
    /// <summary>Comprobaciones fallidas seguidas para dar el proxy por caído; evita avisos por un fallo aislado.</summary>
    public const int FailuresBeforeUnreachable = 2;

    private readonly IProxyProbe _probe;
    private readonly string _host;
    private readonly ushort _port;
    private readonly TimeSpan _healthyInterval;
    private readonly TimeSpan _unreachableInterval;
    private readonly CancellationTokenSource _lifetime = new();
    private readonly SemaphoreSlim _wake = new(0, 1);
    private Task? _loop;
    private int _consecutiveFailures;

    public ConnectionHealthMonitor(IProxyProbe probe, string host, ushort port, TimeSpan healthyInterval, TimeSpan unreachableInterval)
    {
        _probe = probe;
        _host = host;
        _port = port;
        _healthyInterval = healthyInterval;
        _unreachableInterval = unreachableInterval;
    }

    public ConnectionHealth Health { get; private set; } = ConnectionHealth.Healthy;

    /// <summary>Se invoca fuera del hilo de la interfaz.</summary>
    public event EventHandler<ConnectionHealth>? HealthChanged;

    public void Start()
    {
        if (_loop is not null)
        {
            throw new InvalidOperationException("El monitor ya está iniciado.");
        }
        NetworkChange.NetworkAddressChanged += OnNetworkChanged;
        NetworkChange.NetworkAvailabilityChanged += OnNetworkAvailabilityChanged;
        _loop = RunAsync(_lifetime.Token);
    }

    /// <summary>Adelanta la siguiente comprobación.</summary>
    public void CheckNow()
    {
        try
        {
            if (_wake.CurrentCount == 0)
            {
                _wake.Release();
            }
        }
        catch (Exception exception) when (exception is SemaphoreFullException or ObjectDisposedException)
        {
        }
    }

    public async ValueTask DisposeAsync()
    {
        NetworkChange.NetworkAddressChanged -= OnNetworkChanged;
        NetworkChange.NetworkAvailabilityChanged -= OnNetworkAvailabilityChanged;
        await _lifetime.CancelAsync().ConfigureAwait(false);
        if (_loop is not null)
        {
            try
            {
                await _loop.ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
            }
        }
        _lifetime.Dispose();
        _wake.Dispose();
    }

    private async Task RunAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            var interval = Health == ConnectionHealth.Healthy ? _healthyInterval : _unreachableInterval;
            try
            {
                await _wake.WaitAsync(interval, cancellationToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                return;
            }

            bool reachable;
            try
            {
                reachable = await _probe.IsReachableAsync(_host, _port, cancellationToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception)
            {
                reachable = false;
            }
            Record(reachable);
        }
    }

    private void Record(bool reachable)
    {
        if (reachable)
        {
            _consecutiveFailures = 0;
            SetHealth(ConnectionHealth.Healthy);
            return;
        }
        _consecutiveFailures++;
        if (_consecutiveFailures >= FailuresBeforeUnreachable)
        {
            SetHealth(ConnectionHealth.Unreachable);
        }
        else
        {
            // Un fallo aislado se confirma enseguida en lugar de esperar el intervalo completo.
            CheckNow();
        }
    }

    private void SetHealth(ConnectionHealth health)
    {
        if (Health == health)
        {
            return;
        }
        Health = health;
        HealthChanged?.Invoke(this, health);
    }

    private void OnNetworkChanged(object? sender, EventArgs e) => CheckNow();

    private void OnNetworkAvailabilityChanged(object? sender, NetworkAvailabilityEventArgs e) => CheckNow();
}
