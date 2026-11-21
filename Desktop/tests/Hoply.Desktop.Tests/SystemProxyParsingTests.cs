using Hoply.Desktop.Core.SystemProxy;

namespace Hoply.Desktop.Tests;

public sealed class SystemProxyParsingTests
{
    private static readonly string[] EnabledServices = ["Wi-Fi", "USB 10/100/1000 LAN"];

    [Fact]
    public void ListsOnlyEnabledMacServices()
    {
        const string output = """
            An asterisk (*) denotes that a network service is disabled.
            Wi-Fi
            *Thunderbolt Bridge
            USB 10/100/1000 LAN
            """;

        Assert.Equal(EnabledServices, MacSystemProxy.ParseServices(output));
    }

    [Theory]
    [InlineData("URL: http://proxy/pac\nEnabled: Yes", "http://proxy/pac")]
    [InlineData("URL: http://proxy/pac\nEnabled: No", null)]
    [InlineData("URL: (null)\nEnabled: No", null)]
    public void ReadsPreviousMacAutoProxy(string output, string? expected)
    {
        Assert.Equal(expected, MacSystemProxy.ParseEnabledUrl(output));
    }

    [Fact]
    public void QuotesGVariantStrings()
    {
        Assert.Equal("'http://127.0.0.1:1080/proxy.pac'", GnomeSystemProxy.Quote("http://127.0.0.1:1080/proxy.pac"));
        Assert.Equal(@"'a\'b'", GnomeSystemProxy.Quote("a'b"));
    }
}
