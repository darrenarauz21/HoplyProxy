namespace Hoply.Desktop.Core.Usbmux;

/// <summary>Un iPhone visto por usbmuxd.</summary>
/// <param name="Id">Identificador de la sesión de usbmuxd; cambia al reconectar el cable.</param>
/// <param name="SerialNumber">UDID del dispositivo.</param>
/// <param name="IsUsb">Conectado por cable (usbmuxd también lista dispositivos por red).</param>
public sealed record UsbDevice(int Id, string SerialNumber, bool IsUsb);

public interface IUsbmuxClient
{
    Task<IReadOnlyList<UsbDevice>> ListDevicesAsync(CancellationToken cancellationToken);

    /// <summary>Abre un túnel TCP hasta un puerto del iPhone. El flujo devuelto es del llamador.</summary>
    Task<Stream> ConnectAsync(int deviceId, ushort devicePort, CancellationToken cancellationToken);
}
