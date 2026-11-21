import Foundation
import Network
import Socks5

/// Interpreta `host:puerto` de una solicitud HTTP como destino de salida.
/// Admite nombres de host, IPv4 e IPv6 entre corchetes.
enum HttpAuthority {
    private static let maximumPortDigits = 5

    /// `defaultPort` se usa cuando el texto no incluye puerto; si es `nil`, el puerto es obligatorio.
    static func destination(from text: String, defaultPort: UInt16?) -> Socks5Destination? {
        let hostText: Substring
        let portText: Substring?

        if text.hasPrefix("[") {
            guard let closing = text.firstIndex(of: "]") else { return nil }
            hostText = text[text.index(after: text.startIndex)..<closing]
            let remainder = text[text.index(after: closing)...]
            if remainder.isEmpty {
                portText = nil
            } else {
                guard remainder.hasPrefix(":") else { return nil }
                portText = remainder.dropFirst()
            }
            guard let address = IPv6Address(String(hostText)) else { return nil }
            return makeDestination(address: .ipv6([UInt8](address.rawValue)), portText: portText, defaultPort: defaultPort)
        }

        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        switch parts.count {
        case 1:
            hostText = parts[0]
            portText = nil
        case 2:
            hostText = parts[0]
            portText = parts[1]
        default:
            return nil
        }

        if let ipv4 = parseIPv4(hostText) {
            return makeDestination(address: .ipv4(ipv4), portText: portText, defaultPort: defaultPort)
        }
        guard Socks5Address.isValidDomainName(hostText.utf8) else { return nil }
        return makeDestination(address: .domain(String(hostText)), portText: portText, defaultPort: defaultPort)
    }

    private static func makeDestination(address: Socks5Address, portText: Substring?, defaultPort: UInt16?) -> Socks5Destination? {
        let port: UInt16
        if let portText {
            guard let parsed = parsePort(portText) else { return nil }
            port = parsed
        } else {
            guard let defaultPort else { return nil }
            port = defaultPort
        }
        return Socks5Destination(address: address, port: port)
    }

    private static func parsePort(_ text: Substring) -> UInt16? {
        guard !text.isEmpty,
              text.count <= maximumPortDigits,
              text.allSatisfy({ $0.isASCII && $0.isNumber }),
              let port = UInt16(text),
              port != 0 else { return nil }
        return port
    }

    /// Solo la forma decimal con cuatro octetos; otras formas se tratan como nombres de host.
    private static func parseIPv4(_ text: Substring) -> [UInt8]? {
        let octets = text.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return nil }
        var bytes: [UInt8] = []
        for octet in octets {
            guard (1...3).contains(octet.count),
                  octet.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let value = UInt8(octet) else { return nil }
            bytes.append(value)
        }
        return bytes
    }
}
