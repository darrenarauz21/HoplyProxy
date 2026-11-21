/// Dirección de destino tal como la envía el cliente.
public enum Socks5Address: Equatable, Sendable {
    /// 4 bytes en orden de red.
    case ipv4([UInt8])
    /// 16 bytes en orden de red.
    case ipv6([UInt8])
    /// Nombre de host; la resolución DNS ocurre en el servidor.
    case domain(String)
}

/// Destino solicitado por el cliente.
public struct Socks5Destination: Equatable, Sendable {
    public let address: Socks5Address
    public let port: UInt16

    public init(address: Socks5Address, port: UInt16) {
        self.address = address
        self.port = port
    }
}

extension Socks5Address {
    /// Longitud máxima de un nombre de host en el protocolo SOCKS5.
    public static let maximumDomainNameLength = 255

    /// Acepta solo letras, dígitos, guion, punto y guion bajo. Se aplica a cualquier nombre de host
    /// recibido de un cliente, sea por SOCKS5 o por HTTP.
    public static func isValidDomainName<Bytes: Collection>(_ bytes: Bytes) -> Bool where Bytes.Element == UInt8 {
        guard !bytes.isEmpty, bytes.count <= maximumDomainNameLength else { return false }
        return bytes.allSatisfy(isAllowedHostnameByte)
    }

    private static func isAllowedHostnameByte(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "a")...UInt8(ascii: "z"),
             UInt8(ascii: "A")...UInt8(ascii: "Z"),
             UInt8(ascii: "0")...UInt8(ascii: "9"),
             UInt8(ascii: "-"),
             UInt8(ascii: "."),
             UInt8(ascii: "_"):
            return true
        default:
            return false
        }
    }
}
