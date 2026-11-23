namespace Hoply.Desktop.Core.Connection;

/// <summary>Por qué no se pudo establecer la conexión. La interfaz decide el texto de cada caso.</summary>
public enum ConnectionFailure
{
    InvalidOptions,
    /// <summary>El servicio de dispositivos de Apple (usbmuxd) no responde.</summary>
    UsbServiceUnavailable,
    /// <summary>No hay ningún iPhone conectado por cable.</summary>
    DeviceNotFound,
    /// <summary>Otro programa ya usa el puerto local.</summary>
    PortInUse,
    SystemProxyFailed,
    /// <summary>No se pudieron definir las variables de entorno del usuario.</summary>
    EnvironmentProxyFailed,
}

public sealed class ConnectionException : Exception
{
    public ConnectionException(ConnectionFailure failure, Exception? innerException = null)
        : base(failure.ToString(), innerException)
    {
        Failure = failure;
    }

    public ConnectionFailure Failure { get; }
}
