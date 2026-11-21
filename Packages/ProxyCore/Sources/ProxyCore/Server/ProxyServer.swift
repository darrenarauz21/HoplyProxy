import Foundation
import Network

/// Servidor proxy (SOCKS5 y HTTP en el mismo puerto) que reenvía el tráfico de la laptop
/// por los datos móviles del iPhone.
/// Todo el estado interno se accede únicamente desde `queue`, por eso la conformidad
/// con `Sendable` se declara de forma manual.
public final class ProxyServer: ProxyServerControlling, @unchecked Sendable {
    private let configuration: ProxyServerConfiguration
    private let transport: InboundTransport
    private let connector: OutboundConnector
    private let accessPolicy: ClientAccessPolicy
    private let queue = DispatchQueue(label: "ProxyCore.ProxyServer")
    private let activity = ProxyActivityRecorder()
    private let statisticsInterval: TimeInterval
    private var sessions: [UUID: ConnectionSession] = [:]
    private var stateHandler: (@Sendable (ProxyServerState) -> Void)?
    private var statisticsHandler: (@Sendable (ProxyTrafficStatistics) -> Void)?
    private var statisticsTimer: DispatchSourceTimer?
    private var state: ProxyServerState = .stopped {
        didSet {
            guard state != oldValue else { return }
            stateHandler?(state)
        }
    }

    /// Servidor de producción: escucha por USB o Wi-Fi según la configuración y sale por datos móviles.
    public convenience init(configuration: ProxyServerConfiguration = .default) {
        self.init(
            configuration: configuration,
            transport: NetworkListenerTransport.make(for: configuration.listenScope),
            connector: NetworkOutboundConnector.cellular(connectTimeout: configuration.connectTimeout)
        )
    }

    /// Frecuencia con la que se publican las estadísticas.
    static let defaultStatisticsInterval: TimeInterval = 1

    init(
        configuration: ProxyServerConfiguration,
        transport: InboundTransport,
        connector: OutboundConnector,
        statisticsInterval: TimeInterval = ProxyServer.defaultStatisticsInterval
    ) {
        self.configuration = configuration
        self.transport = transport
        self.connector = connector
        self.statisticsInterval = statisticsInterval
        self.accessPolicy = ClientAccessPolicy(
            scope: configuration.listenScope,
            allowedClients: configuration.allowedClients
        )
    }

    deinit {
        statisticsTimer?.cancel()
    }

    public func setStateHandler(_ handler: @escaping @Sendable (ProxyServerState) -> Void) {
        queue.async {
            self.stateHandler = handler
            handler(self.state)
        }
    }

    public func setStatisticsHandler(_ handler: @escaping @Sendable (ProxyTrafficStatistics) -> Void) {
        queue.async {
            self.statisticsHandler = handler
            self.publishStatistics()
        }
    }

    public func setEventHandler(_ handler: @escaping @Sendable (ProxyEvent) -> Void) {
        queue.async {
            self.activity.eventHandler = { event in handler(event) }
        }
    }

    public func start() {
        queue.async { self.startOnQueue() }
    }

    public func stop() {
        queue.async { self.stopOnQueue() }
    }

    // MARK: - Ciclo de vida

    private func startOnQueue() {
        guard !state.isActive else { return }
        guard configuration.isValid else {
            state = .failed(.invalidConfiguration)
            return
        }
        state = .starting
        transport.eventHandler = { [weak self] event in
            self?.handle(event)
        }
        transport.start(port: configuration.port, queue: queue)
        startStatisticsTimer()
    }

    private func stopOnQueue() {
        shutDown()
        state = .stopped
    }

    private func shutDown() {
        stopStatisticsTimer()
        publishStatistics()
        transport.eventHandler = nil
        transport.stop()
        let activeSessions = Array(sessions.values)
        sessions.removeAll()
        activeSessions.forEach { $0.close() }
    }

    private func handle(_ event: InboundTransportEvent) {
        switch event {
        case .ready(let port):
            state = .running(port: port, activeConnections: sessions.count)
        case .failed(let failure):
            shutDown()
            state = .failed(failure)
        case .newConnection(let connection):
            accept(connection)
        }
    }

    // MARK: - Sesiones

    private func accept(_ connection: NWConnection) {
        guard case .running = state else {
            connection.cancel()
            return
        }
        guard accessPolicy.allows(connection.endpoint) else {
            reject(connection, reason: .notAllowed)
            return
        }
        guard sessions.count < configuration.maximumConnections else {
            reject(connection, reason: .connectionLimitReached)
            return
        }

        activity.recordAcceptedConnection()
        let session = ConnectionSession(
            client: connection,
            connector: connector,
            configuration: configuration,
            queue: queue,
            activity: activity
        )
        sessions[session.id] = session
        session.start { [weak self] id in
            self?.sessionDidClose(id)
        }
        publishActiveConnections()
    }

    private func reject(_ connection: NWConnection, reason: ClientRejectionReason) {
        activity.recordRejectedConnection(from: connection.endpoint, reason: reason)
        connection.cancel()
    }

    private func sessionDidClose(_ id: UUID) {
        guard sessions.removeValue(forKey: id) != nil else { return }
        publishActiveConnections()
    }

    private func publishActiveConnections() {
        guard case let .running(port, _) = state else { return }
        state = .running(port: port, activeConnections: sessions.count)
    }

    // MARK: - Estadísticas

    private func startStatisticsTimer() {
        stopStatisticsTimer()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.setEventHandler { [weak self] in
            self?.publishStatistics()
        }
        timer.schedule(deadline: .now() + statisticsInterval, repeating: statisticsInterval)
        timer.resume()
        statisticsTimer = timer
    }

    private func stopStatisticsTimer() {
        statisticsTimer?.cancel()
        statisticsTimer = nil
    }

    /// Se publica en cada intervalo aunque no haya cambios, para que la velocidad mostrada vuelva a cero.
    private func publishStatistics() {
        statisticsHandler?(activity.statistics)
    }
}
