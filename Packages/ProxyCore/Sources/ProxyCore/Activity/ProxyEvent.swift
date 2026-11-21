import Foundation

/// Suceso relevante para diagnosticar la conexión. Nunca incluye destinos ni contenido,
/// solo la dirección de la laptop cuando ayuda a autorizarla.
public struct ProxyEvent: Equatable, Sendable {
    public let date: Date
    public let kind: ProxyEventKind

    public init(date: Date, kind: ProxyEventKind) {
        self.date = date
        self.kind = kind
    }
}

public enum ProxyEventKind: Hashable, Sendable {
    /// `address` es la IPv4 del cliente, o `nil` si no se pudo determinar.
    case clientRejected(address: String?, reason: ClientRejectionReason)
    case authenticationFailed(address: String?)
    case destinationUnreachable(OutboundFailureReason)
}

public enum ClientRejectionReason: Hashable, Sendable {
    /// En Wi-Fi, la dirección no figura entre los clientes autorizados.
    case notAllowed
    case connectionLimitReached
}

public enum OutboundFailureReason: Hashable, Sendable {
    /// Sin ruta por datos móviles.
    case networkUnreachable
    case hostUnreachable
    case connectionRefused
    case timedOut
    case other
}
