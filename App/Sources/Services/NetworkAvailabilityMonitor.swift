import Network

/// Interfaces del iPhone que el proxy necesita.
struct NetworkAvailability: Equatable {
    /// Los datos móviles pueden usarse para salir a internet.
    var isCellularAvailable: Bool
    /// El iPhone está conectado a una red Wi-Fi.
    var isWiFiAvailable: Bool

    /// Valor inicial hasta recibir la primera lectura, para no mostrar avisos falsos al abrir la app.
    static let assumedAvailable = NetworkAvailability(isCellularAvailable: true, isWiFiAvailable: true)
}

@MainActor
protocol NetworkAvailabilityMonitoring: AnyObject {
    /// Se invoca en el hilo principal cada vez que cambia la disponibilidad.
    var onChange: ((NetworkAvailability) -> Void)? { get set }
    func start()
}

/// Observa por separado la interfaz de datos móviles y la Wi-Fi; el monitor por defecto
/// solo informa de la ruta principal y no revela si hay datos móviles con Wi-Fi conectada.
@MainActor
final class NetworkAvailabilityMonitor: NetworkAvailabilityMonitoring {
    var onChange: ((NetworkAvailability) -> Void)?

    private let cellularMonitor = NWPathMonitor(requiredInterfaceType: .cellular)
    private let wifiMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let queue = DispatchQueue(label: "Hoply.NetworkAvailabilityMonitor")
    private var availability = NetworkAvailability.assumedAvailable
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true
        cellularMonitor.pathUpdateHandler = { [weak self] path in
            let isAvailable = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.update { $0.isCellularAvailable = isAvailable }
            }
        }
        wifiMonitor.pathUpdateHandler = { [weak self] path in
            let isAvailable = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.update { $0.isWiFiAvailable = isAvailable }
            }
        }
        cellularMonitor.start(queue: queue)
        wifiMonitor.start(queue: queue)
    }

    private func update(_ change: (inout NetworkAvailability) -> Void) {
        var updated = availability
        change(&updated)
        availability = updated
        onChange?(updated)
    }
}
