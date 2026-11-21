using System.Globalization;
using System.Text;
using System.Xml;
using System.Xml.Linq;

namespace Hoply.Desktop.Core.Usbmux;

/// <summary>
/// Lo justo de las listas de propiedades XML de Apple para hablar con usbmuxd: diccionarios con texto, enteros,
/// booleanos, listas y diccionarios anidados. No procesa DTD ni entidades externas.
/// </summary>
internal static class PlistXml
{
    private const int MaxDocumentCharacters = 1 << 20;

    public static byte[] Encode(IEnumerable<KeyValuePair<string, object>> values)
    {
        var dictionary = new XElement("dict");
        foreach (var (key, value) in values)
        {
            dictionary.Add(new XElement("key", key));
            dictionary.Add(EncodeValue(value));
        }

        var document = new XDocument(
            new XDocumentType("plist", "-//Apple//DTD PLIST 1.0//EN", "http://www.apple.com/DTDs/PropertyList-1.0.dtd", null),
            new XElement("plist", new XAttribute("version", "1.0"), dictionary));

        using var stream = new MemoryStream();
        var settings = new XmlWriterSettings { Encoding = new UTF8Encoding(false), Indent = false };
        using (var writer = XmlWriter.Create(stream, settings))
        {
            document.Save(writer);
        }
        return stream.ToArray();
    }

    public static IReadOnlyDictionary<string, object?> DecodeDictionary(byte[] data)
    {
        var settings = new XmlReaderSettings
        {
            DtdProcessing = DtdProcessing.Ignore,
            XmlResolver = null,
            MaxCharactersInDocument = MaxDocumentCharacters,
        };

        try
        {
            using var stream = new MemoryStream(data, writable: false);
            using var reader = XmlReader.Create(stream, settings);
            var root = XDocument.Load(reader).Root;
            var dictionary = root?.Element("dict") ?? throw new UsbmuxException(UsbmuxError.ProtocolError);
            return DecodeDict(dictionary);
        }
        catch (Exception exception) when (exception is XmlException or FormatException or OverflowException)
        {
            throw new UsbmuxException(UsbmuxError.ProtocolError, exception);
        }
    }

    private static XElement EncodeValue(object value) => value switch
    {
        string text => new XElement("string", text),
        int number => new XElement("integer", number.ToString(CultureInfo.InvariantCulture)),
        long number => new XElement("integer", number.ToString(CultureInfo.InvariantCulture)),
        bool flag => new XElement(flag ? "true" : "false"),
        _ => throw new ArgumentException($"Tipo no admitido en plist: {value.GetType().Name}", nameof(value)),
    };

    private static Dictionary<string, object?> DecodeDict(XElement dictionary)
    {
        var result = new Dictionary<string, object?>(StringComparer.Ordinal);
        string? pendingKey = null;
        foreach (var element in dictionary.Elements())
        {
            if (element.Name.LocalName == "key")
            {
                pendingKey = element.Value;
                continue;
            }
            if (pendingKey is not null)
            {
                result[pendingKey] = DecodeValue(element);
                pendingKey = null;
            }
        }
        return result;
    }

    private static object? DecodeValue(XElement element) => element.Name.LocalName switch
    {
        "string" => element.Value,
        "integer" => long.Parse(element.Value.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture),
        "real" => double.Parse(element.Value.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture),
        "true" => true,
        "false" => false,
        "dict" => DecodeDict(element),
        "array" => element.Elements().Select(DecodeValue).ToList(),
        _ => null,
    };
}
