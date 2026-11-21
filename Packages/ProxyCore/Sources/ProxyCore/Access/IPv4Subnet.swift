/// Rango de direcciones IPv4 en notación CIDR, por ejemplo `192.168.1.0/24`.
/// Una dirección sin prefijo equivale a `/32`.
public struct IPv4Subnet: Hashable, Sendable, CustomStringConvertible {
    /// Dirección de red ya enmascarada, en orden de host.
    public let networkAddress: UInt32
    public let prefixLength: UInt8

    public init(address: UInt32, prefixLength: UInt8) {
        let clampedPrefix = min(prefixLength, 32)
        self.prefixLength = clampedPrefix
        self.networkAddress = address & Self.mask(for: clampedPrefix)
    }

    public init?(_ text: String) {
        let parts = text.trimmingWhitespace().split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2,
              let address = Self.parseAddress(parts[0]) else { return nil }

        var prefix: UInt8 = 32
        if parts.count == 2 {
            guard Self.isDecimal(parts[1]), let parsedPrefix = UInt8(parts[1]), parsedPrefix <= 32 else {
                return nil
            }
            prefix = parsedPrefix
        }
        self.init(address: address, prefixLength: prefix)
    }

    public func contains(_ address: UInt32) -> Bool {
        address & Self.mask(for: prefixLength) == networkAddress
    }

    public var description: String {
        "\(Self.formatAddress(networkAddress))/\(prefixLength)"
    }

    // MARK: - Utilidades de direcciones

    /// Convierte `a.b.c.d` en un entero en orden de host.
    public static func parseAddress<Text: StringProtocol>(_ text: Text) -> UInt32? {
        let octets = String(text).split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return nil }

        var value: UInt32 = 0
        for octet in octets {
            guard (1...3).contains(octet.count), isDecimal(octet), let byte = UInt8(octet) else { return nil }
            value = value << 8 | UInt32(byte)
        }
        return value
    }

    public static func formatAddress(_ address: UInt32) -> String {
        [24, 16, 8, 0].map { String((address >> UInt32($0)) & 0xFF) }.joined(separator: ".")
    }

    public static func mask(for prefixLength: UInt8) -> UInt32 {
        guard prefixLength > 0 else { return 0 }
        return UInt32.max << UInt32(32 - min(prefixLength, 32))
    }

    private static func isDecimal<Text: StringProtocol>(_ text: Text) -> Bool {
        !text.isEmpty && text.utf8.allSatisfy { $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }
    }
}

private extension String {
    func trimmingWhitespace() -> Substring {
        let isWhitespace: (Character) -> Bool = { $0 == " " || $0 == "\t" }
        guard let start = firstIndex(where: { !isWhitespace($0) }),
              let end = lastIndex(where: { !isWhitespace($0) }) else { return "" }
        return self[start...end]
    }
}
