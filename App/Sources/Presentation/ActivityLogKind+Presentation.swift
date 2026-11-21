import ProxyCore
import SwiftUI

extension ActivityLogKind {
    var messageKey: LocalizedStringKey {
        switch self {
        case .serverStarted(let port):
            return "log.serverStarted \(Int(port))"
        case .serverStopped:
            return "log.serverStopped"
        case .serverFailed(let failure):
            return failure.messageKey
        case .automaticRestart:
            return "log.automaticRestart"
        case .cellularLost:
            return "log.cellularLost"
        case .cellularRestored:
            return "log.cellularRestored"
        case .proxy(let event):
            return event.messageKey
        }
    }

    var symbolName: String {
        switch self {
        case .serverStarted:
            return "play.circle"
        case .serverStopped:
            return "stop.circle"
        case .serverFailed:
            return "exclamationmark.octagon"
        case .automaticRestart:
            return "arrow.clockwise.circle"
        case .cellularLost:
            return "antenna.radiowaves.left.and.right.slash"
        case .cellularRestored:
            return "antenna.radiowaves.left.and.right"
        case .proxy(.clientRejected):
            return "hand.raised"
        case .proxy(.authenticationFailed):
            return "key"
        case .proxy(.destinationUnreachable):
            return "xmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .serverStarted, .cellularRestored:
            return Theme.success
        case .serverStopped, .automaticRestart:
            return .secondary
        case .serverFailed:
            return Theme.danger
        case .cellularLost, .proxy:
            return Theme.warning
        }
    }

    /// Dirección de la laptop rechazada, para copiarla a la lista de clientes autorizados.
    var clientAddress: String? {
        switch self {
        case let .proxy(.clientRejected(address, _)), let .proxy(.authenticationFailed(address)):
            return address
        default:
            return nil
        }
    }
}

extension ProxyEventKind {
    var messageKey: LocalizedStringKey {
        switch self {
        case let .clientRejected(address, .notAllowed):
            return "log.rejected.notAllowed \(address ?? "-")"
        case .clientRejected(_, .connectionLimitReached):
            return "log.rejected.limit"
        case .authenticationFailed(let address):
            return "log.authenticationFailed \(address ?? "-")"
        case .destinationUnreachable(let reason):
            switch reason {
            case .networkUnreachable:
                return "log.unreachable.network"
            case .hostUnreachable:
                return "log.unreachable.host"
            case .connectionRefused:
                return "log.unreachable.refused"
            case .timedOut:
                return "log.unreachable.timeout"
            case .other:
                return "log.unreachable.other"
            }
        }
    }
}
