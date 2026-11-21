import Foundation
import Network

/// Acumula estadísticas y emite eventos del servidor. Solo se usa desde la cola del servidor.
/// Los eventos idénticos se agrupan durante `eventThrottleInterval` para que una ráfaga de fallos
/// (por ejemplo, al perder la señal) no sature el registro ni la interfaz.
final class ProxyActivityRecorder {
    static let eventThrottleInterval: TimeInterval = 2
    /// Límite de claves recordadas para la agrupación; evita crecer sin control con muchas direcciones.
    private static let maximumTrackedEventKinds = 256

    private(set) var statistics = ProxyTrafficStatistics.zero
    var eventHandler: ((ProxyEvent) -> Void)?

    private let now: () -> Date
    private var lastEmissionDates: [ProxyEventKind: Date] = [:]

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func recordAcceptedConnection() {
        statistics.acceptedConnections += 1
    }

    func recordRejectedConnection(from endpoint: NWEndpoint, reason: ClientRejectionReason) {
        statistics.rejectedConnections += 1
        emit(.clientRejected(address: Self.address(of: endpoint), reason: reason))
    }

    func recordAuthenticationFailure(from endpoint: NWEndpoint) {
        emit(.authenticationFailed(address: Self.address(of: endpoint)))
    }

    func recordOutboundFailure(_ error: OutboundConnectionError) {
        statistics.failedConnections += 1
        emit(.destinationUnreachable(error.failureReason))
    }

    func recordTransfer(_ byteCount: Int, direction: TrafficDirection) {
        guard byteCount > 0 else { return }
        switch direction {
        case .upstream:
            statistics.bytesUploaded &+= UInt64(byteCount)
        case .downstream:
            statistics.bytesDownloaded &+= UInt64(byteCount)
        }
    }

    private func emit(_ kind: ProxyEventKind) {
        let date = now()
        if let last = lastEmissionDates[kind], date.timeIntervalSince(last) < Self.eventThrottleInterval {
            return
        }
        if lastEmissionDates.count >= Self.maximumTrackedEventKinds {
            lastEmissionDates.removeAll(keepingCapacity: true)
        }
        lastEmissionDates[kind] = date
        eventHandler?(ProxyEvent(date: date, kind: kind))
    }

    private static func address(of endpoint: NWEndpoint) -> String? {
        endpoint.ipv4HostValue.map(IPv4Subnet.formatAddress)
    }
}

extension OutboundConnectionError {
    var failureReason: OutboundFailureReason {
        switch self {
        case .networkUnreachable:
            return .networkUnreachable
        case .hostUnreachable:
            return .hostUnreachable
        case .connectionRefused:
            return .connectionRefused
        case .timedOut:
            return .timedOut
        case .invalidDestination, .failed:
            return .other
        }
    }
}
