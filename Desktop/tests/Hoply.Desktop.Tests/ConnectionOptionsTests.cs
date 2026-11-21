using Hoply.Desktop.Core.Connection;

namespace Hoply.Desktop.Tests;

public sealed class ConnectionOptionsTests
{
    [Fact]
    public void UsbAlwaysUsesLoopback()
    {
        var options = ConnectionOptions.Create(ConnectionMode.Usb, "192.168.1.20", 1080, configureSystemProxy: true);

        Assert.Equal("127.0.0.1", options.Host);
        Assert.Equal("http://127.0.0.1:1080/proxy.pac", options.PacUrl);
        Assert.Empty(ConnectionOptionsValidator.Validate(options));
    }

    [Theory]
    [InlineData("192.168.1.20", true)]
    [InlineData(" 10.0.0.5 ", true)]
    [InlineData("", false)]
    [InlineData("192.168.1", false)]
    [InlineData("1", false)]
    [InlineData("127.0.0.1", false)]
    [InlineData("0.0.0.0", false)]
    [InlineData("256.1.1.1", false)]
    [InlineData("iphone.local", false)]
    public void ValidatesWiFiHost(string host, bool isValid)
    {
        var options = ConnectionOptions.Create(ConnectionMode.WiFi, host, 1080, configureSystemProxy: false);

        Assert.Equal(isValid, !ConnectionOptionsValidator.Validate(options).Contains(ConnectionIssue.InvalidHost));
    }

    [Theory]
    [InlineData(0, false)]
    [InlineData(1023, false)]
    [InlineData(1024, true)]
    [InlineData(65535, true)]
    public void ValidatesPort(int port, bool isValid)
    {
        var options = ConnectionOptions.Create(ConnectionMode.Usb, string.Empty, (ushort)port, configureSystemProxy: false);

        Assert.Equal(isValid, !ConnectionOptionsValidator.Validate(options).Contains(ConnectionIssue.InvalidPort));
    }

    [Fact]
    public void BuildsTerminalCommands()
    {
        var options = ConnectionOptions.Create(ConnectionMode.WiFi, "192.168.1.20", 1080, configureSystemProxy: false);

        Assert.Equal(
            "export http_proxy=http://192.168.1.20:1080 https_proxy=http://192.168.1.20:1080 ALL_PROXY=socks5h://192.168.1.20:1080",
            TerminalProxyCommand.Posix(options));
        Assert.StartsWith("$env:HTTP_PROXY=\"http://192.168.1.20:1080\"", TerminalProxyCommand.PowerShell(options));
    }
}
