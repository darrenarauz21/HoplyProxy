import Darwin

/// Red Wi-Fi a la que está conectado el iPhone.
public struct LocalWiFiNetwork: Equatable, Sendable {
    /// Dirección del iPhone en orden de host.
    public let address: UInt32
    public let subnet: IPv4Subnet

    public init(address: UInt32, subnet: IPv4Subnet) {
        self.address = address
        self.subnet = subnet
    }

    public var addressText: String {
        IPv4Subnet.formatAddress(address)
    }
}

/// Lee la dirección IPv4 de la interfaz Wi-Fi.
public enum WiFiInterfaceReader {
    /// En iPhone la interfaz Wi-Fi es `en0`.
    public static let defaultInterfaceName = "en0"

    public static func currentNetwork(interfaceName: String = defaultInterfaceName) -> LocalWiFiNetwork? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard entry.ifa_flags & UInt32(IFF_UP) != 0,
                  String(cString: entry.ifa_name) == interfaceName,
                  let address = entry.ifa_addr,
                  let netmask = entry.ifa_netmask,
                  address.pointee.sa_family == sa_family_t(AF_INET) else { continue }

            let hostAddress = ipv4Value(of: address)
            let prefixLength = UInt8(ipv4Value(of: netmask).nonzeroBitCount)
            return LocalWiFiNetwork(
                address: hostAddress,
                subnet: IPv4Subnet(address: hostAddress, prefixLength: prefixLength)
            )
        }
        return nil
    }

    private static func ipv4Value(of socketAddress: UnsafeMutablePointer<sockaddr>) -> UInt32 {
        socketAddress.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
            UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
        }
    }
}
