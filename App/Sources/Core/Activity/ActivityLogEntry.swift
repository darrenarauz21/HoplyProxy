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
    /// El modo en segundo plano quedó activo (audio en silencio sonando).
    case backgroundModeOn
    /// No se pudo activar el audio en silencio: con la pantalla bloqueada el proxy se pausará.
    case backgroundModeFailed
    /// El audio se cortó (llamada, otra app) y se reanudó.
    case backgroundModeResumed
    /// La app pasó a segundo plano sin el modo en segundo plano: iOS pausará el proxy.
    case pausedInBackground
    case proxy(ProxyEventKind)
}
