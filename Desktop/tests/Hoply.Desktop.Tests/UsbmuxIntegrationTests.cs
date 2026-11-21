using System.Net;
using System.Net.Sockets;
using System.Text;
using Hoply.Desktop.Core.Usbmux;

namespace Hoply.Desktop.Tests;

/// <summary>Habla con un usbmuxd simulado y con un iPhone simulado (un servidor de eco).</summary>
public sealed class UsbmuxIntegrationTests
{
    private static readonly TimeSpan TestTimeout = TimeSpan.FromSeconds(10);

    [Fact]
    public async Task ListsDevicesFromUsbmuxd()
    {
        using var timeout = new CancellationTokenSource(TestTimeout);
        using var usbmuxd = new TcpListener(IPAddress.Loopback, 0);
        usbmuxd.Start();
        var server = RespondOnceAsync(usbmuxd, """
            <?xml version="1.0" encoding="UTF-8"?>
            <plist version="1.0"><dict><key>DeviceList</key><array>
              <dict><key>Properties</key><dict>
                <key>ConnectionType</key><string>USB</string>
                <key>DeviceID</key><integer>5</integer>
                <key>SerialNumber</key><string>abc</string>
              </dict></dict>
              <dict><key>Properties</key><dict>
                <key>ConnectionType</key><string>Network</string>
                <key>DeviceID</key><integer>6</integer>
              </dict></dict>
            </array></dict></plist>
            """, timeout.Token);

        var client = new UsbmuxClient((IPEndPoint)usbmuxd.LocalEndpoint);
        var devices = await client.ListDevicesAsync(timeout.Token);
        var request = await server;

        Assert.Contains("<string>ListDevices</string>", request);
        Assert.Equal(new[] { new UsbDevice(5, "abc", true), new UsbDevice(6, string.Empty, false) }, devices);
    }

    [Fact]
    public async Task ReportsRefusedConnections()
    {
        using var timeout = new CancellationTokenSource(TestTimeout);
        using var usbmuxd = new TcpListener(IPAddress.Loopback, 0);
        usbmuxd.Start();
        var server = RespondOnceAsync(usbmuxd, ResultPlist(3), timeout.Token);

        var client = new UsbmuxClient((IPEndPoint)usbmuxd.LocalEndpoint);
        var error = await Assert.ThrowsAsync<UsbmuxException>(() => client.ConnectAsync(5, 1080, timeout.Token));
        var request = await server;

        Assert.Equal(UsbmuxError.ConnectionRefused, error.Error);
        Assert.Contains("<integer>14340</integer>", request);
    }

    [Fact]
    public async Task ReportsMissingService()
    {
        using var unused = new TcpListener(IPAddress.Loopback, 0);
        unused.Start();
        var endpoint = (IPEndPoint)unused.LocalEndpoint;
        unused.Stop();

        var client = new UsbmuxClient(endpoint);
        var error = await Assert.ThrowsAsync<UsbmuxException>(() => client.ListDevicesAsync(CancellationToken.None));

        Assert.Equal(UsbmuxError.ServiceUnavailable, error.Error);
    }

    [Fact]
    public async Task ForwardsBytesInBothDirections()
    {
        using var timeout = new CancellationTokenSource(TestTimeout);
        using var device = new TcpListener(IPAddress.Loopback, 0);
        device.Start();
        _ = EchoAsync(device, timeout.Token);

        var localPort = FreePort();
        await using var forwarder = new UsbPortForwarder(new LoopbackUsbmux((IPEndPoint)device.LocalEndpoint), localPort, 1080);
        forwarder.Start();

        using var laptop = new TcpClient();
        await laptop.ConnectAsync(IPAddress.Loopback, localPort, timeout.Token);
        var stream = laptop.GetStream();
        var message = Encoding.ASCII.GetBytes("hola iPhone");
        await stream.WriteAsync(message, timeout.Token);

        var echoed = new byte[message.Length];
        await stream.ReadExactlyAsync(echoed, timeout.Token);
        Assert.Equal(message, echoed);
    }

    [Fact]
    public async Task ReportsSessionsWithoutDevice()
    {
        using var timeout = new CancellationTokenSource(TestTimeout);
        var localPort = FreePort();
        await using var forwarder = new UsbPortForwarder(new LoopbackUsbmux(null), localPort, 1080);
        var failure = new TaskCompletionSource<UsbmuxError>(TaskCreationOptions.RunContinuationsAsynchronously);
        forwarder.SessionFailed += (_, exception) => failure.TrySetResult(exception.Error);
        forwarder.Start();

        using var laptop = new TcpClient();
        await laptop.ConnectAsync(IPAddress.Loopback, localPort, timeout.Token);

        Assert.Equal(UsbmuxError.DeviceNotFound, await failure.Task.WaitAsync(timeout.Token));
    }

    private static string ResultPlist(int number) =>
        $"<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>MessageType</key><string>Result</string><key>Number</key><integer>{number}</integer></dict></plist>";

    private static async Task<string> RespondOnceAsync(TcpListener listener, string responsePlist, CancellationToken cancellationToken)
    {
        using var socket = await listener.AcceptTcpClientAsync(cancellationToken);
        var stream = socket.GetStream();

        var header = new byte[UsbmuxFraming.HeaderLength];
        await stream.ReadExactlyAsync(header, cancellationToken);
        var payload = new byte[UsbmuxFraming.PayloadLength(header)];
        await stream.ReadExactlyAsync(payload, cancellationToken);

        await stream.WriteAsync(UsbmuxFraming.Frame(Encoding.UTF8.GetBytes(responsePlist), tag: 1), cancellationToken);
        return Encoding.UTF8.GetString(payload);
    }

    private static async Task EchoAsync(TcpListener listener, CancellationToken cancellationToken)
    {
        using var socket = await listener.AcceptTcpClientAsync(cancellationToken);
        var stream = socket.GetStream();
        await stream.CopyToAsync(stream, cancellationToken);
    }

    private static ushort FreePort()
    {
        using var probe = new TcpListener(IPAddress.Loopback, 0);
        probe.Start();
        return (ushort)((IPEndPoint)probe.LocalEndpoint).Port;
    }

    /// <summary>Un usbmuxd falso: el «iPhone» es un servidor local, o no hay ninguno.</summary>
    private sealed class LoopbackUsbmux : IUsbmuxClient
    {
        private readonly IPEndPoint? _device;

        public LoopbackUsbmux(IPEndPoint? device)
        {
            _device = device;
        }

        public Task<IReadOnlyList<UsbDevice>> ListDevicesAsync(CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<UsbDevice>>(_device is null ? [] : [new UsbDevice(1, "test", true)]);

        public async Task<Stream> ConnectAsync(int deviceId, ushort devicePort, CancellationToken cancellationToken)
        {
            var client = new TcpClient();
            await client.ConnectAsync(_device!, cancellationToken);
            return new NetworkStream(client.Client, ownsSocket: true);
        }
    }
}
