/// Estado observable del servidor.
public enum ProxyServerState: Equatable, Sendable {
    case stopped
    case starting
    case running(port: UInt16, activeConnections: Int)
    case failed(ProxyServerFailure)

    public var isActive: Bool {
        switch self {
        case .starting, .running:
            return true
        case .stopped, .failed:
            return false
        }
    }
}

/// Motivos por los que el servidor no pudo iniciar o dejó de funcionar.
public enum ProxyServerFailure: Error, Equatable, Sendable {
    case invalidConfiguration
    case portUnavailable(UInt16)
    case networkUnavailable
    case localNetworkDenied
    case listenerFailed
}
