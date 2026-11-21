using System.Net;
using System.Net.Sockets;

namespace Hoply.Desktop.Core.Usbmux;

/// <summary>
/// Cliente de usbmuxd, el servicio que comparten iTunes, Apple Devices y libimobiledevice. Cada petición usa su propio
/// socket; tras un «Connect» aceptado, ese socket queda como túnel directo al puerto del iPhone.
/// </summary>
public sealed class UsbmuxClient : IUsbmuxClient
{
    private const string ProgramName = "Hoply";
    private const string ClientVersion = "hoply-desktop";
    private const string UsbConnectionType = "USB";

    private readonly EndPoint _endpoint;
    private int _nextTag;

    public UsbmuxClient(EndPoint endpoint)
    {
        _endpoint = endpoint;
    }

    public static UsbmuxClient CreateDefault() => new(UsbmuxEndpoint.Resolve());

    public async Task<IReadOnlyList<UsbDevice>> ListDevicesAsync(CancellationToken cancellationToken)
    {
        using var socket = await OpenAsync(cancellationToken).ConfigureAwait(false);
        await using var stream = new NetworkStream(socket, ownsSocket: false);
        var response = await ExchangeAsync(stream, Request("ListDevices"), cancellationToken).ConfigureAwait(false);

        if (!response.TryGetValue("DeviceList", out var listValue) || listValue is not List<object?> entries)
        {
            throw new UsbmuxException(UsbmuxError.ProtocolError);
        }
        return entries.OfType<Dictionary<string, object?>>().Select(ParseDevice).OfType<UsbDevice>().ToList();
    }

    public async Task<Stream> ConnectAsync(int deviceId, ushort devicePort, CancellationToken cancellationToken)
    {
        var socket = await OpenAsync(cancellationToken).ConfigureAwait(false);
        var stream = new NetworkStream(socket, ownsSocket: true);
        try
        {
            var request = Request("Connect");
            request["DeviceID"] = deviceId;
            request["PortNumber"] = UsbmuxFraming.ToNetworkPort(devicePort);
            var response = await ExchangeAsync(stream, request, cancellationToken).ConfigureAwait(false);
            ThrowIfFailed(response);
            return stream;
        }
        catch
        {
            await stream.DisposeAsync().ConfigureAwait(false);
            throw;
        }
    }

    private async Task<Socket> OpenAsync(CancellationToken cancellationToken)
    {
        var socket = _endpoint is UnixDomainSocketEndPoint
            ? new Socket(AddressFamily.Unix, SocketType.Stream, ProtocolType.Unspecified)
            : new Socket(_endpoint.AddressFamily, SocketType.Stream, ProtocolType.Tcp);
        try
        {
            await socket.ConnectAsync(_endpoint, cancellationToken).ConfigureAwait(false);
            return socket;
        }
        catch (SocketException exception)
        {
            socket.Dispose();
            throw new UsbmuxException(UsbmuxError.ServiceUnavailable, exception);
        }
        catch
        {
            socket.Dispose();
            throw;
        }
    }

    private static Dictionary<string, object> Request(string messageType) => new(StringComparer.Ordinal)
    {
        ["MessageType"] = messageType,
        ["ProgName"] = ProgramName,
        ["ClientVersionString"] = ClientVersion,
    };

    private async Task<IReadOnlyDictionary<string, object?>> ExchangeAsync(
        Stream stream, Dictionary<string, object> request, CancellationToken cancellationToken)
    {
        var tag = (uint)Interlocked.Increment(ref _nextTag);
        try
        {
            await stream.WriteAsync(UsbmuxFraming.Frame(PlistXml.Encode(request), tag), cancellationToken).ConfigureAwait(false);

            var header = new byte[UsbmuxFraming.HeaderLength];
            await stream.ReadExactlyAsync(header, cancellationToken).ConfigureAwait(false);
            var payload = new byte[UsbmuxFraming.PayloadLength(header)];
            await stream.ReadExactlyAsync(payload, cancellationToken).ConfigureAwait(false);
            return PlistXml.DecodeDictionary(payload);
        }
        catch (Exception exception) when (exception is IOException or EndOfStreamException or SocketException)
        {
            throw new UsbmuxException(UsbmuxError.ServiceUnavailable, exception);
        }
    }

    private static void ThrowIfFailed(IReadOnlyDictionary<string, object?> response)
    {
        if (!response.TryGetValue("Number", out var value) || value is not long code)
        {
            throw new UsbmuxException(UsbmuxError.ProtocolError);
        }
        if (code != 0)
        {
            throw new UsbmuxException(code switch
            {
                2 => UsbmuxError.DeviceNotFound,
                3 => UsbmuxError.ConnectionRefused,
                _ => UsbmuxError.Rejected,
            });
        }
    }

    private static UsbDevice? ParseDevice(Dictionary<string, object?> entry)
    {
        if (entry.GetValueOrDefault("Properties") is not Dictionary<string, object?> properties
            || properties.GetValueOrDefault("DeviceID") is not long id
            || id is < 0 or > int.MaxValue)
        {
            return null;
        }
        var serial = properties.GetValueOrDefault("SerialNumber") as string ?? string.Empty;
        var isUsb = string.Equals(properties.GetValueOrDefault("ConnectionType") as string, UsbConnectionType, StringComparison.Ordinal);
        return new UsbDevice((int)id, serial, isUsb);
    }
}
