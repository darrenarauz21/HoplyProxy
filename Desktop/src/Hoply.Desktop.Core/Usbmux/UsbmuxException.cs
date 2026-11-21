namespace Hoply.Desktop.Core.Usbmux;

public enum UsbmuxError
{
    /// <summary>usbmuxd no está instalado o no está en ejecución.</summary>
    ServiceUnavailable,
    /// <summary>La respuesta no tiene el formato esperado.</summary>
    ProtocolError,
    /// <summary>No hay un iPhone conectado por cable, o se desconectó.</summary>
    DeviceNotFound,
    /// <summary>El iPhone no acepta conexiones en ese puerto: el proxy no está iniciado.</summary>
    ConnectionRefused,
    /// <summary>usbmuxd rechazó la petición por otro motivo.</summary>
    Rejected,
}

public sealed class UsbmuxException : Exception
{
    public UsbmuxException(UsbmuxError error, Exception? innerException = null)
        : base(error.ToString(), innerException)
    {
        Error = error;
    }

    public UsbmuxError Error { get; }
}
