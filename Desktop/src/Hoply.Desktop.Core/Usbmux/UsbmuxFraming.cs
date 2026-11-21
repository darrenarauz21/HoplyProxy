using System.Buffers.Binary;

namespace Hoply.Desktop.Core.Usbmux;

/// <summary>
/// Encabezado de los mensajes de usbmuxd: longitud total, versión, tipo y etiqueta, en 32 bits little endian.
/// Se usa la versión 1 con mensajes plist (tipo 8).
/// </summary>
internal static class UsbmuxFraming
{
    public const int HeaderLength = 16;
    public const int MaxPayloadLength = 1 << 20;
    private const uint ProtocolVersion = 1;
    private const uint PlistMessageType = 8;

    public static byte[] Frame(ReadOnlySpan<byte> payload, uint tag)
    {
        var message = new byte[HeaderLength + payload.Length];
        var span = message.AsSpan();
        BinaryPrimitives.WriteUInt32LittleEndian(span[0..4], (uint)message.Length);
        BinaryPrimitives.WriteUInt32LittleEndian(span[4..8], ProtocolVersion);
        BinaryPrimitives.WriteUInt32LittleEndian(span[8..12], PlistMessageType);
        BinaryPrimitives.WriteUInt32LittleEndian(span[12..16], tag);
        payload.CopyTo(span[HeaderLength..]);
        return message;
    }

    /// <summary>Longitud del cuerpo indicada por un encabezado recibido.</summary>
    public static int PayloadLength(ReadOnlySpan<byte> header)
    {
        var total = BinaryPrimitives.ReadUInt32LittleEndian(header[0..4]);
        if (total < HeaderLength || total - HeaderLength > MaxPayloadLength)
        {
            throw new UsbmuxException(UsbmuxError.ProtocolError);
        }
        return (int)(total - HeaderLength);
    }

    /// <summary>usbmuxd espera el puerto del dispositivo en orden de red dentro de un entero.</summary>
    public static int ToNetworkPort(ushort port) => (ushort)((port << 8) | (port >> 8));
}
