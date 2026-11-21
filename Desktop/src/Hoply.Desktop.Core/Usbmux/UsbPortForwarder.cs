using System.Net;
using System.Net.Sockets;

namespace Hoply.Desktop.Core.Usbmux;

/// <summary>
/// Reenvía un puerto local de la laptop al mismo puerto del iPhone por el cable, como «ios forward» o «iproxy».
/// Busca el iPhone en cada conexión, así que sigue funcionando si se desconecta y vuelve a conectar el cable.
/// </summary>
public sealed class UsbPortForwarder : IAsyncDisposable
{
    private const int CopyBufferSize = 64 * 1024;

    private readonly IUsbmuxClient _usbmux;
    private readonly ushort _localPort;
    private readonly ushort _devicePort;
    private readonly CancellationTokenSource _lifetime = new();
    private TcpListener? _listener;
    private Task? _acceptLoop;
    private int _activeSessions;

    public UsbPortForwarder(IUsbmuxClient usbmux, ushort localPort, ushort devicePort)
    {
        _usbmux = usbmux;
        _localPort = localPort;
        _devicePort = devicePort;
    }

    /// <summary>Una conexión de la laptop no pudo llegar al iPhone. Se invoca fuera del hilo de la interfaz.</summary>
    public event EventHandler<UsbmuxException>? SessionFailed;

    public int ActiveSessions => Volatile.Read(ref _activeSessions);

    /// <summary>Empieza a escuchar solo en 127.0.0.1. Lanza <see cref="SocketException"/> si el puerto está ocupado.</summary>
    public void Start()
    {
        if (_listener is not null)
        {
            throw new InvalidOperationException("El reenvío ya está iniciado.");
        }
        var listener = new TcpListener(IPAddress.Loopback, _localPort);
        if (OperatingSystem.IsWindows())
        {
            // Sin esto, Windows permitiría que otro programa compartiera el puerto.
            listener.ExclusiveAddressUse = true;
        }
        listener.Start();
        _listener = listener;
        _acceptLoop = AcceptLoopAsync(listener, _lifetime.Token);
    }

    public async ValueTask DisposeAsync()
    {
        await _lifetime.CancelAsync().ConfigureAwait(false);
        _listener?.Stop();
        if (_acceptLoop is not null)
        {
            try
            {
                await _acceptLoop.ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
            }
        }
        _lifetime.Dispose();
    }

    private async Task AcceptLoopAsync(TcpListener listener, CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            TcpClient client;
            try
            {
                client = await listener.AcceptTcpClientAsync(cancellationToken).ConfigureAwait(false);
            }
            catch (Exception exception) when (exception is OperationCanceledException or ObjectDisposedException)
            {
                return;
            }
            catch (SocketException)
            {
                // Un cliente que se va antes de ser aceptado no detiene el reenvío.
                continue;
            }
            _ = HandleSessionAsync(client, cancellationToken);
        }
    }

    private async Task HandleSessionAsync(TcpClient client, CancellationToken cancellationToken)
    {
        Interlocked.Increment(ref _activeSessions);
        using var session = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        try
        {
            using (client)
            {
                client.NoDelay = true;
                var device = await FindUsbDeviceAsync(session.Token).ConfigureAwait(false);
                await using var remote = await _usbmux.ConnectAsync(device.Id, _devicePort, session.Token).ConfigureAwait(false);
                var local = client.GetStream();

                var upload = PumpAsync(local, remote, () => ShutdownSend(remote), session);
                var download = PumpAsync(remote, local, () => ShutdownSend(local), session);
                await Task.WhenAll(upload, download).ConfigureAwait(false);
            }
        }
        catch (UsbmuxException exception)
        {
            SessionFailed?.Invoke(this, exception);
        }
        catch (Exception exception) when (exception is OperationCanceledException or IOException or SocketException or ObjectDisposedException)
        {
            // Cierre normal de una de las dos puntas o de la app.
        }
        finally
        {
            Interlocked.Decrement(ref _activeSessions);
        }
    }

    private async Task<UsbDevice> FindUsbDeviceAsync(CancellationToken cancellationToken)
    {
        var devices = await _usbmux.ListDevicesAsync(cancellationToken).ConfigureAwait(false);
        return devices.FirstOrDefault(device => device.IsUsb) ?? throw new UsbmuxException(UsbmuxError.DeviceNotFound);
    }

    /// <summary>Copia en un sentido. Al terminar cierra solo la escritura del otro lado; ante un error, corta la sesión.</summary>
    private static async Task PumpAsync(Stream source, Stream destination, Action onCompleted, CancellationTokenSource session)
    {
        try
        {
            await source.CopyToAsync(destination, CopyBufferSize, session.Token).ConfigureAwait(false);
            onCompleted();
        }
        catch (Exception exception) when (exception is OperationCanceledException or IOException or SocketException or ObjectDisposedException)
        {
            await session.CancelAsync().ConfigureAwait(false);
        }
    }

    private static void ShutdownSend(Stream stream)
    {
        if (stream is NetworkStream network)
        {
            try
            {
                network.Socket.Shutdown(SocketShutdown.Send);
            }
            catch (Exception exception) when (exception is SocketException or ObjectDisposedException)
            {
            }
        }
    }
}
