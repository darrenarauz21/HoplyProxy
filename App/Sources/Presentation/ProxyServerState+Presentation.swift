import ProxyCore
import SwiftUI

extension ProxyServerState {
    var statusTitleKey: LocalizedStringKey {
        switch self {
        case .stopped:
            return "home.status.stopped"
        case .starting:
            return "home.status.starting"
        case .running:
            return "home.status.running"
        case .failed:
            return "home.status.failed"
        }
    }

    var statusColor: Color {
        switch self {
        case .stopped:
            return Theme.tertiaryText
        case .starting:
            return Theme.accent
        case .running:
            return Theme.success
        case .failed:
            return Theme.danger
        }
    }

    var statusSymbol: String {
        switch self {
        case .stopped:
            return "power"
        case .starting:
            return "hourglass"
        case .running:
            return "personalhotspot"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var toggleActionKey: LocalizedStringKey {
        isActive ? "home.action.stop" : "home.action.start"
    }

    var activeConnections: Int {
        if case let .running(_, activeConnections) = self {
            return activeConnections
        }
        return 0
    }

    var failureMessageKey: LocalizedStringKey? {
        guard case let .failed(failure) = self else { return nil }
        return failure.messageKey
    }
}

extension ProxyServerFailure {
    var messageKey: LocalizedStringKey {
        switch self {
        case .invalidConfiguration:
            return "home.failure.configuration"
        case .portUnavailable(let port):
            return "home.failure.portUnavailable \(Int(port))"
        case .networkUnavailable:
            return "home.failure.network"
        case .localNetworkDenied:
            return "home.failure.localNetwork"
        case .listenerFailed:
            return "home.failure.listener"
        }
    }
}
