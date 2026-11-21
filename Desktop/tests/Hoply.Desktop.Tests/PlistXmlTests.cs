using System.Text;
using Hoply.Desktop.Core.Usbmux;

namespace Hoply.Desktop.Tests;

public sealed class PlistXmlTests
{
    [Fact]
    public void EncodesAndDecodesFlatDictionary()
    {
        var encoded = PlistXml.Encode(new Dictionary<string, object>
        {
            ["MessageType"] = "Connect",
            ["DeviceID"] = 7,
            ["Enabled"] = true,
        });

        var decoded = PlistXml.DecodeDictionary(encoded);

        Assert.Equal("Connect", decoded["MessageType"]);
        Assert.Equal(7L, decoded["DeviceID"]);
        Assert.Equal(true, decoded["Enabled"]);
    }

    [Fact]
    public void DecodesNestedDeviceList()
    {
        const string xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict>
              <key>DeviceList</key>
              <array><dict>
                <key>DeviceID</key><integer>3</integer>
                <key>Properties</key><dict>
                  <key>ConnectionType</key><string>USB</string>
                  <key>DeviceID</key><integer>3</integer>
                </dict>
              </dict></array>
            </dict></plist>
            """;

        var decoded = PlistXml.DecodeDictionary(Encoding.UTF8.GetBytes(xml));

        var list = Assert.IsType<List<object?>>(decoded["DeviceList"]);
        var entry = Assert.IsType<Dictionary<string, object?>>(Assert.Single(list));
        var properties = Assert.IsType<Dictionary<string, object?>>(entry["Properties"]);
        Assert.Equal("USB", properties["ConnectionType"]);
    }

    [Fact]
    public void RejectsMalformedDocuments()
    {
        var error = Assert.Throws<UsbmuxException>(() => PlistXml.DecodeDictionary(Encoding.UTF8.GetBytes("<plist><dict>")));

        Assert.Equal(UsbmuxError.ProtocolError, error.Error);
    }

    [Fact]
    public void ConvertsPortToNetworkOrder()
    {
        Assert.Equal(0x3804, UsbmuxFraming.ToNetworkPort(1080));
    }
}
