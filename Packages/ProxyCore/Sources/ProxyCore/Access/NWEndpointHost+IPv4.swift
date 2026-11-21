import Foundation
import Network

extension NWEndpoint.Host {
    /// Dirección IPv4 en orden de host. Incluye direcciones IPv6 mapeadas (`::ffff:a.b.c.d`),
    /// que es como algunos listeners de doble pila presentan a los clientes IPv4.
    var ipv4Value: UInt32? {
        switch self {
        case .ipv4(let address):
            return Self.integer(from: address.rawValue)
        case .ipv6(let address):
            let bytes = [UInt8](address.rawValue)
            guard bytes.count == 16,
                  bytes.prefix(10).allSatisfy({ $0 == 0 }),
                  bytes[10] == 0xFF, bytes[11] == 0xFF else { return nil }
            return Self.integer(from: Data(bytes.suffix(4)))
        default:
            return nil
        }
    }

    private static func integer(from data: Data) -> UInt32? {
        guard data.count == 4 else { return nil }
        return data.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
    }
}

extension NWEndpoint {
    var ipv4HostValue: UInt32? {
        guard case let .hostPort(host, _) = self else { return nil }
        return host.ipv4Value
    }
}
