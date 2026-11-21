import Foundation
import ProxyCore

/// Entrada del registro de actividad. Solo contiene sucesos de diagnóstico, nunca destinos.
struct ActivityLogEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let kind: ActivityLogKind
}

enum ActivityLogKind: Equatable {
    case serverStarted(port: UInt16)
    case serverStopped
    case serverFailed(ProxyServerFailure)
    case automaticRestart
    case cellularLost
    case cellularRestored
    case proxy(ProxyEventKind)
}
