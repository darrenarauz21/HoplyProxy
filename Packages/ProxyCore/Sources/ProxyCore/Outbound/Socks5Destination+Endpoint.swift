import Foundation
import Network
import Socks5

extension Socks5Destination {
    /// Endpoint de red equivalente, o `nil` si la dirección o el puerto no son válidos.
    var networkEndpoint: NWEndpoint? {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else { return nil }

        let host: NWEndpoint.Host
        switch address {
        case .ipv4(let bytes):
            guard let ipv4 = IPv4Address(Data(bytes)) else { return nil }
            host = .ipv4(ipv4)
        case .ipv6(let bytes):
            guard let ipv6 = IPv6Address(Data(bytes)) else { return nil }
            host = .ipv6(ipv6)
        case .domain(let name):
            host = .name(name, nil)
        }
        return .hostPort(host: host, port: endpointPort)
    }
}
