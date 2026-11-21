/// Solicitud del cliente tras la negociación de autenticación.
public struct Socks5Request: Equatable, Sendable {
    public let command: Socks5Command
    public let destination: Socks5Destination

    public init(command: Socks5Command, destination: Socks5Destination) {
        self.command = command
        self.destination = destination
    }

    private static let headerLength = 4
    private static let portLength = 2
    private static let ipv4Length = 4
    private static let ipv6Length = 16

    /// Formato: VER(1) CMD(1) RSV(1) ATYP(1) DST.ADDR(variable) DST.PORT(2).
    public static func parse(_ buffer: [UInt8]) throws -> Socks5ParseResult<Socks5Request> {
        guard let version = buffer.first else { return .needMoreData }
        guard version == Socks5Constants.version else {
            throw Socks5ProtocolError.unsupportedVersion(version)
        }
        guard buffer.count >= headerLength else { return .needMoreData }

        guard let command = Socks5Command(rawValue: buffer[1]) else {
            throw Socks5ProtocolError.unsupportedCommand(buffer[1])
        }
        guard buffer[2] == Socks5Constants.reservedByte else {
            throw Socks5ProtocolError.invalidReservedByte(buffer[2])
        }
        guard let addressType = Socks5AddressType(rawValue: buffer[3]) else {
            throw Socks5ProtocolError.unsupportedAddressType(buffer[3])
        }

        let addressStart = headerLength
        let address: Socks5Address
        let addressEnd: Int

        switch addressType {
        case .ipv4:
            addressEnd = addressStart + ipv4Length
            guard buffer.count >= addressEnd + portLength else { return .needMoreData }
            address = .ipv4(Array(buffer[addressStart..<addressEnd]))

        case .ipv6:
            addressEnd = addressStart + ipv6Length
            guard buffer.count >= addressEnd + portLength else { return .needMoreData }
            address = .ipv6(Array(buffer[addressStart..<addressEnd]))

        case .domainName:
            guard buffer.count > addressStart else { return .needMoreData }
            let nameLength = Int(buffer[addressStart])
            guard nameLength > 0 else { throw Socks5ProtocolError.invalidDomainName }

            let nameStart = addressStart + 1
            addressEnd = nameStart + nameLength
            guard buffer.count >= addressEnd + portLength else { return .needMoreData }

            let nameBytes = buffer[nameStart..<addressEnd]
            guard Socks5Address.isValidDomainName(nameBytes) else {
                throw Socks5ProtocolError.invalidDomainName
            }
            address = .domain(String(decoding: nameBytes, as: UTF8.self))
        }

        let port = UInt16(buffer[addressEnd]) << 8 | UInt16(buffer[addressEnd + 1])
        guard port != 0 else { throw Socks5ProtocolError.invalidPort }

        let request = Socks5Request(
            command: command,
            destination: Socks5Destination(address: address, port: port)
        )
        return .complete(request, consumed: addressEnd + portLength)
    }
}
