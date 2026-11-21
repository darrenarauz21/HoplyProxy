import Foundation

/// Credenciales del encabezado `Proxy-Authorization` con el esquema Basic (RFC 7617).
struct HttpProxyAuthorization: Equatable {
    /// Cubre usuario y contraseña de hasta 255 bytes cada uno codificados en Base64.
    private static let maximumEncodedLength = 1024
    private static let scheme = "basic"

    let username: [UInt8]
    let password: [UInt8]

    static func parse(_ headerValue: String) -> HttpProxyAuthorization? {
        let parts = headerValue.split(separator: " ", maxSplits: 1)
        guard parts.count == 2,
              parts[0].lowercased() == scheme else { return nil }

        let encoded = parts[1].trimmingCharacters(in: .whitespaces)
        guard encoded.count <= maximumEncodedLength,
              let decoded = Data(base64Encoded: encoded) else { return nil }

        let bytes = [UInt8](decoded)
        guard let separator = bytes.firstIndex(of: UInt8(ascii: ":")) else { return nil }
        return HttpProxyAuthorization(
            username: Array(bytes[..<separator]),
            password: Array(bytes[(separator + 1)...])
        )
    }
}
