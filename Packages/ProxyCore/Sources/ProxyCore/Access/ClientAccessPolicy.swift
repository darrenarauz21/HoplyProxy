import Network

/// Decide qué equipos pueden conectarse al servidor.
struct ClientAccessPolicy {
    let scope: ListenScope
    let allowedClients: [IPv4Subnet]

    func allows(_ remoteEndpoint: NWEndpoint) -> Bool {
        switch scope {
        case .loopback:
            // El listener solo acepta conexiones locales del propio iPhone (reenvío USB).
            return true
        case .wifi:
            guard let address = remoteEndpoint.ipv4HostValue else { return false }
            return allowedClients.contains { $0.contains(address) }
        }
    }
}
