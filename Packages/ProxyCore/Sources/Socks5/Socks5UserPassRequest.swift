/// Credenciales enviadas por el cliente tras elegir el método usuario/contraseña (RFC 1929).
public struct Socks5UserPassRequest: Equatable, Sendable {
    public static let version: UInt8 = 0x01

    public let username: [UInt8]
    public let password: [UInt8]

    public init(username: [UInt8], password: [UInt8]) {
        self.username = username
        self.password = password
    }

    /// Formato: VER(1) ULEN(1) UNAME(ULEN) PLEN(1) PASSWD(PLEN).
    public static func parse(_ buffer: [UInt8]) throws -> Socks5ParseResult<Socks5UserPassRequest> {
        guard let receivedVersion = buffer.first else { return .needMoreData }
        guard receivedVersion == version else {
            throw Socks5ProtocolError.unsupportedAuthenticationVersion(receivedVersion)
        }
        guard buffer.count >= 2 else { return .needMoreData }

        let usernameLength = Int(buffer[1])
        guard usernameLength > 0 else { throw Socks5ProtocolError.invalidCredentialsFormat }

        let usernameEnd = 2 + usernameLength
        guard buffer.count > usernameEnd else { return .needMoreData }

        let passwordLength = Int(buffer[usernameEnd])
        guard passwordLength > 0 else { throw Socks5ProtocolError.invalidCredentialsFormat }

        let passwordStart = usernameEnd + 1
        let passwordEnd = passwordStart + passwordLength
        guard buffer.count >= passwordEnd else { return .needMoreData }

        let request = Socks5UserPassRequest(
            username: Array(buffer[2..<usernameEnd]),
            password: Array(buffer[passwordStart..<passwordEnd])
        )
        return .complete(request, consumed: passwordEnd)
    }
}
