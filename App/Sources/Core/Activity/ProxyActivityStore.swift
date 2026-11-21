import Foundation
import ProxyCore

/// Estadísticas de la sesión actual y registro reciente de sucesos. Se publica por separado del
/// controlador para que las actualizaciones periódicas solo redibujen las vistas que las muestran.
@MainActor
final class ProxyActivityStore: ObservableObject {
    /// Entradas que se conservan; las más antiguas se descartan.
    static let logCapacity = 200

    @Published private(set) var statistics = ProxyTrafficStatistics.zero
    /// Bytes por segundo, calculados entre las dos últimas lecturas.
    @Published private(set) var downloadRate: Double = 0
    @Published private(set) var uploadRate: Double = 0
    /// Más recientes primero.
    @Published private(set) var entries: [ActivityLogEntry] = []

    private var lastSample: (statistics: ProxyTrafficStatistics, date: Date)?
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    /// Llamar al iniciar un servidor nuevo: sus contadores empiezan en cero.
    func beginSession() {
        statistics = .zero
        downloadRate = 0
        uploadRate = 0
        lastSample = nil
    }

    func endSession() {
        downloadRate = 0
        uploadRate = 0
        lastSample = nil
    }

    func apply(_ newStatistics: ProxyTrafficStatistics) {
        let date = now()
        if let lastSample {
            let elapsed = date.timeIntervalSince(lastSample.date)
            if elapsed > 0 {
                downloadRate = Self.rate(from: lastSample.statistics.bytesDownloaded, to: newStatistics.bytesDownloaded, over: elapsed)
                uploadRate = Self.rate(from: lastSample.statistics.bytesUploaded, to: newStatistics.bytesUploaded, over: elapsed)
            }
        }
        lastSample = (newStatistics, date)
        statistics = newStatistics
    }

    func log(_ kind: ActivityLogKind) {
        entries.insert(ActivityLogEntry(date: now(), kind: kind), at: 0)
        if entries.count > Self.logCapacity {
            entries.removeLast(entries.count - Self.logCapacity)
        }
    }

    func clearLog() {
        entries.removeAll()
    }

    private static func rate(from previous: UInt64, to current: UInt64, over interval: TimeInterval) -> Double {
        guard current >= previous else { return 0 }
        return Double(current - previous) / interval
    }
}
