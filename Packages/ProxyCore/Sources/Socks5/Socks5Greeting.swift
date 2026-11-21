/// Saludo inicial del cliente: versión y métodos de autenticación que ofrece.
public struct Socks5Greeting: Equatable, Sendable {
    /// Valores crudos ofrecidos por el cliente, incluidos los que el servidor no conoce.
    public let methods: [UInt8]

    public init(methods: [UInt8]) {
        self.methods = methods
    }

    /// Formato: VER(1) NMETHODS(1) METHODS(NMETHODS).
    public static func parse(_ buffer: [UInt8]) throws -> Socks5ParseResult<Socks5Greeting> {
        guard let version = buffer.first else { return .needMoreData }
        guard version == Socks5Constants.version else {
            throw Socks5ProtocolError.unsupportedVersion(version)
        }
        guard buffer.count >= 2 else { return .needMoreData }

        let methodCount = Int(buffer[1])
        guard methodCount > 0 else { throw Socks5ProtocolError.noAuthenticationMethods }

        let totalLength = 2 + methodCount
        guard buffer.count >= totalLength else { return .needMoreData }

        let greeting = Socks5Greeting(methods: Array(buffer[2..<totalLength]))
        return .complete(greeting, consumed: totalLength)
    }

    /// Devuelve el primer método del servidor, en su orden de preferencia, que el cliente ofrece.
    public func selectMethod(preferredOrder supported: [Socks5AuthMethod]) -> Socks5AuthMethod {
        let match = supported.first { method in
            method != .noAcceptableMethods && methods.contains(method.rawValue)
        }
        return match ?? .noAcceptableMethods
    }
}
