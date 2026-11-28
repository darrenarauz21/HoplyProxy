import Foundation
import Network

/// Cuenta los equipos conectados, no las conexiones. Un navegador abre decenas de conexiones y Hoply Desktop abre una
/// cada pocos segundos para comprobar que el iPhone responde, pero todas vienen del mismo equipo: se agrupan por la
/// dirección de origen (por USB todas llegan desde 127.0.0.1, así que la laptop cuenta como un solo equipo).
/// Un equipo sigue contando mientras tiene conexiones abiertas y durante `idleWindow` después de cerrar la última, para
/// que el número no parpadee entre una petición y la siguiente. Solo se usa desde la cola del servidor.
struct ConnectedDevicesTracker {
    static let idleWindow: TimeInterval = 30

    private var openConnections: [String: Int] = [:]
    private var lastActivity: [String: Date] = [:]

    mutating func connectionOpened(by device: String, at date: Date) {
        openConnections[device, default: 0] += 1
        lastActivity[device] = date
    }

    mutating func connectionClosed(by device: String, at date: Date) {
        guard let count = openConnections[device] else { return }
        if count > 1 {
            openConnections[device] = count - 1
        } else {
            openConnections.removeValue(forKey: device)
        }
        lastActivity[device] = date
    }

    /// Equipos con conexiones abiertas o con actividad reciente. Olvida los que llevan inactivos más de `idleWindow`.
    mutating func count(at date: Date) -> Int {
        lastActivity = lastActivity.filter { device, lastSeen in
            openConnections[device] != nil || date.timeIntervalSince(lastSeen) < Self.idleWindow
        }
        return lastActivity.count
    }

    mutating func reset() {
        openConnections.removeAll()
        lastActivity.removeAll()
    }

    /// Identifica el equipo por su dirección, sin el puerto de origen, que cambia en cada conexión.
    static func device(of endpoint: NWEndpoint) -> String {
        if let address = endpoint.ipv4HostValue {
            return IPv4Subnet.formatAddress(address)
        }
        if case let .hostPort(host, _) = endpoint {
            return "\(host)"
        }
        return "\(endpoint)"
    }
}
