/// Errores de formato detectados al analizar mensajes del cliente.
public enum Socks5ProtocolError: Error, Equatable, Sendable {
    case unsupportedVersion(UInt8)
    case noAuthenticationMethods
    case invalidReservedByte(UInt8)
    case unsupportedCommand(UInt8)
    case unsupportedAddressType(UInt8)
    case invalidDomainName
    case invalidPort
    case unsupportedAuthenticationVersion(UInt8)
    case invalidCredentialsFormat

    /// Código que se envía al cliente cuando el error ocurre durante la solicitud.
    public var replyCode: Socks5ReplyCode {
        switch self {
        case .unsupportedCommand:
            return .commandNotSupported
        case .unsupportedAddressType:
            return .addressTypeNotSupported
        case .unsupportedVersion,
             .noAuthenticationMethods,
             .invalidReservedByte,
             .invalidDomainName,
             .invalidPort,
             .unsupportedAuthenticationVersion,
             .invalidCredentialsFormat:
            return .generalFailure
        }
    }
}
