import Foundation
import Network
import Socks5

/// Abre la conexión hacia el destino solicitado por el cliente.
protocol OutboundConnector: AnyObject {
    /// `completion` se invoca una sola vez en `queue`. En caso de éxito la conexión ya está lista.
    func connect(
        to destination: Socks5Destination,
        queue: DispatchQueue,
        completion: @escaping (Result<NWConnection, OutboundConnectionError>) -> Void
    )
}

/// Fallos al conectar con el destino, traducibles a códigos SOCKS5.
enum OutboundConnectionError: Error, Equatable {
    case invalidDestination
    case networkUnreachable
    case hostUnreachable
    case connectionRefused
    case timedOut
    case failed

    init(_ error: NWError) {
        switch error {
        case .posix(let code):
            switch code {
            case .ECONNREFUSED:
                self = .connectionRefused
            case .ENETUNREACH, .ENETDOWN:
                self = .networkUnreachable
            case .EHOSTUNREACH, .EHOSTDOWN:
                self = .hostUnreachable
            case .ETIMEDOUT:
                self = .timedOut
            default:
                self = .failed
            }
        case .dns:
            self = .hostUnreachable
        default:
            self = .failed
        }
    }

    var replyCode: Socks5ReplyCode {
        switch self {
        case .invalidDestination, .failed:
            return .generalFailure
        case .networkUnreachable:
            return .networkUnreachable
        case .hostUnreachable, .timedOut:
            return .hostUnreachable
        case .connectionRefused:
            return .connectionRefused
        }
    }
}
