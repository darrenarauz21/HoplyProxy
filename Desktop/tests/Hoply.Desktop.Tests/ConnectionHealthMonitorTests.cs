using System.Collections.Concurrent;
using Hoply.Desktop.Core.Connection;
using Hoply.Desktop.Core.SystemProxy;

namespace Hoply.Desktop.Tests;

public sealed class ConnectionHealthMonitorTests
{
    private static readonly TimeSpan Fast = TimeSpan.FromMilliseconds(20);
    private static readonly TimeSpan WaitLimit = TimeSpan.FromSeconds(5);

    [Fact]
    public async Task ReportsUnreachableAfterConsecutiveFailuresAndRecovers()
    {
        var probe = new ScriptedProbe(reachable: true);
        var changes = new BlockingCollection<ConnectionHealth>();
        await using var monitor = new ConnectionHealthMonitor(probe, "127.0.0.1", 1080, Fast, Fast);
        monitor.HealthChanged += (_, health) => changes.Add(health);
        monitor.Start();

        probe.Reachable = false;
        Assert.True(changes.TryTake(out var lost, WaitLimit));
        Assert.Equal(ConnectionHealth.Unreachable, lost);
        Assert.True(probe.Calls >= ConnectionHealthMonitor.FailuresBeforeUnreachable);

        probe.Reachable = true;
        Assert.True(changes.TryTake(out var back, WaitLimit));
        Assert.Equal(ConnectionHealth.Healthy, back);
    }

    [Fact]
    public async Task IgnoresASingleFailure()
    {
        var probe = new ScriptedProbe(reachable: true) { FailOnce = true };
        var changes = new BlockingCollection<ConnectionHealth>();
        await using var monitor = new ConnectionHealthMonitor(probe, "127.0.0.1", 1080, Fast, Fast);
        monitor.HealthChanged += (_, health) => changes.Add(health);
        monitor.Start();

        Assert.False(changes.TryTake(out _, TimeSpan.FromMilliseconds(300)));
        Assert.Equal(ConnectionHealth.Healthy, monitor.Health);
    }

    [Fact]
    public async Task CheckNowProbesWithoutWaitingForTheInterval()
    {
        var probe = new ScriptedProbe(reachable: true);
        await using var monitor = new ConnectionHealthMonitor(probe, "127.0.0.1", 1080, TimeSpan.FromMinutes(5), TimeSpan.FromMinutes(5));
        monitor.Start();

        monitor.CheckNow();

        Assert.True(await probe.FirstCall.Task.WaitAsync(WaitLimit));
    }

    [Fact]
    public async Task PacProbeSucceedsOnlyWhenThePacIsServed()
    {
        var listener = new System.Net.Sockets.TcpListener(System.Net.IPAddress.Loopback, 0);
        listener.Start();
        var port = (ushort)((System.Net.IPEndPoint)listener.LocalEndpoint).Port;
        var server = Task.Run(async () =>
        {
            using var client = await listener.AcceptTcpClientAsync();
            var stream = client.GetStream();
            var buffer = new byte[4096];
            _ = await stream.ReadAsync(buffer);
            var body = "function FindProxyForURL(u,h){return \"DIRECT\";}"u8.ToArray();
            await stream.WriteAsync(System.Text.Encoding.ASCII.GetBytes(
                $"HTTP/1.1 200 OK\r\nContent-Length: {body.Length}\r\nConnection: close\r\n\r\n"));
            await stream.WriteAsync(body);
        });

        using var probe = new PacProxyProbe();
        Assert.True(await probe.IsReachableAsync("127.0.0.1", port, CancellationToken.None));
        await server;
        listener.Stop();

        Assert.False(await probe.IsReachableAsync("127.0.0.1", port, CancellationToken.None));
    }

    [Fact]
    public void EnvironmentVariablesPointAtTheProxyAndSkipLocalAddresses()
    {
        var values = EnvironmentProxyVariables.For("http://127.0.0.1:1080");

        Assert.Equal("http://127.0.0.1:1080", values[EnvironmentProxyVariables.HttpProxy]);
        Assert.Equal("http://127.0.0.1:1080", values[EnvironmentProxyVariables.HttpsProxy]);
        Assert.Contains("localhost", values[EnvironmentProxyVariables.NoProxy], StringComparison.Ordinal);
        Assert.Contains("127.0.0.1", values[EnvironmentProxyVariables.NoProxy], StringComparison.Ordinal);
        Assert.Equal(EnvironmentProxyVariables.Names.Order(), values.Keys.Order());
    }

    [Fact]
    public void HttpProxyUrlUsesHostAndPort()
    {
        var options = ConnectionOptions.Create(ConnectionMode.WiFi, " 192.168.1.20 ", 1081, configureSystemProxy: false, configureEnvironmentProxy: true);

        Assert.Equal("http://192.168.1.20:1081", options.HttpProxyUrl);
        Assert.True(options.ConfigureEnvironmentProxy);
    }

    private sealed class ScriptedProbe : IProxyProbe
    {
        private int _calls;
        private volatile bool _reachable;

        public ScriptedProbe(bool reachable) => _reachable = reachable;

        public bool Reachable
        {
            get => _reachable;
            set => _reachable = value;
        }

        public bool FailOnce { get; init; }

        public int Calls => Volatile.Read(ref _calls);

        public TaskCompletionSource<bool> FirstCall { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public Task<bool> IsReachableAsync(string host, ushort port, CancellationToken cancellationToken)
        {
            var call = Interlocked.Increment(ref _calls);
            FirstCall.TrySetResult(true);
            if (FailOnce && call == 1)
            {
                return Task.FromResult(false);
            }
            return Task.FromResult(_reachable);
        }
    }
}
