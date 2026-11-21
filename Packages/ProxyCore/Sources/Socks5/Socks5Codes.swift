/// Valores fijos del protocolo definidos en RFC 1928.
public enum Socks5Constants {
    public static let version: UInt8 = 0x05
    public static let reservedByte: UInt8 = 0x00
}

/// Métodos de autenticación negociados en el saludo inicial.
public enum Socks5AuthMethod: UInt8, Sendable {
    case noAuthentication = 0x00
    case usernamePassword = 0x02
    case noAcceptableMethods = 0xFF
}

/// Comandos que un cliente puede solicitar.
public enum Socks5Command: UInt8, Sendable {
    case connect = 0x01
    case bind = 0x02
    case udpAssociate = 0x03
}

/// Tipos de dirección de destino.
public enum Socks5AddressType: UInt8, Sendable {
    case ipv4 = 0x01
    case domainName = 0x03
    case ipv6 = 0x04
}

/// Códigos de respuesta enviados al cliente tras una solicitud.
public enum Socks5ReplyCode: UInt8, Sendable {
    case succeeded = 0x00
    case generalFailure = 0x01
    case connectionNotAllowed = 0x02
    case networkUnreachable = 0x03
    case hostUnreachable = 0x04
    case connectionRefused = 0x05
    case ttlExpired = 0x06
    case commandNotSupported = 0x07
    case addressTypeNotSupported = 0x08
}
