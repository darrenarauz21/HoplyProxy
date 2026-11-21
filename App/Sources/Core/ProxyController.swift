import Foundation
import ProxyConfig
import ProxyCore

/// Estado compartido de la app: ajustes persistidos, credenciales y ciclo de vida del servidor.
/// Las pantallas lo observan y le delegan todas las acciones.
@MainActor
final class ProxyController: ObservableObject {
    static let usbProxyHost = "127.0.0.1"
    /// Espera tras un cambio de red antes de reiniciar, para no reiniciar varias veces seguidas.
    static let automaticRestartDelayNanoseconds: UInt64 = 2_000_000_000

    @Published private(set) var state: ProxyServerState = .stopped
    @Published private(set) var settings: ProxySettings
    @Published private(set) var password: String?
    @Published private(set) var hasCompletedSetup: Bool
    @Published private(set) var wifiNetwork: LocalWiFiNetwork?
    @Published private(set) var networkAvailability = NetworkAvailability.assumedAvailable
    /// Problemas que impidieron el último inicio.
    @Published private(set) var startIssues: [ProxySettingsIssue] = []

    let activity: ProxyActivityStore
    let signature: SignatureMonitor

    private let settingsStore: ProxySettingsStore
    private let credentialStore: CredentialStore
    private let makeServer: (ProxyServerConfiguration) -> ProxyServerControlling
    private let readWiFiNetwork: () -> LocalWiFiNetwork?
    private let screenAwake: ScreenAwakeControlling
    private let backgroundKeepAlive: BackgroundKeepAliveControlling
    private let networkMonitor: NetworkAvailabilityMonitoring
    private var server: ProxyServerControlling?
    /// Descarta estados tardíos de un servidor ya reemplazado.
    private var serverGeneration = 0
    /// El usuario pidió que el proxy esté activo; permite recuperarlo tras un cambio de red.
    private var wantsRunning = false
    private var restartTask: Task<Void, Never>?

    init(
        settingsStore: ProxySettingsStore,
        credentialStore: CredentialStore,
        makeServer: @escaping (ProxyServerConfiguration) -> ProxyServerControlling,
        readWiFiNetwork: @escaping () -> LocalWiFiNetwork?,
        screenAwake: ScreenAwakeControlling,
        backgroundKeepAlive: BackgroundKeepAliveControlling,
        networkMonitor: NetworkAvailabilityMonitoring,
        activity: ProxyActivityStore,
        signature: SignatureMonitor
    ) {
        self.settingsStore = settingsStore
        self.credentialStore = credentialStore
        self.makeServer = makeServer
        self.readWiFiNetwork = readWiFiNetwork
        self.screenAwake = screenAwake
        self.backgroundKeepAlive = backgroundKeepAlive
        self.networkMonitor = networkMonitor
        self.activity = activity
        self.signature = signature
        settings = settingsStore.loadSettings()
        password = try? credentialStore.loadPassword()
        hasCompletedSetup = settingsStore.hasCompletedSetup
        wifiNetwork = readWiFiNetwork()

        networkMonitor.onChange = { [weak self] availability in
            self?.handleNetworkChange(availability)
        }
        networkMonitor.start()
        signature.applyReminder(enabled: settings.remindsBeforeSignatureExpiry)
    }

    // MARK: - Datos derivados

    var isWiFiUnavailable: Bool {
        settings.transport == .wifi && wifiNetwork == nil
    }

    var isCellularUnavailable: Bool {
        !networkAvailability.isCellularAvailable
    }

    /// Dirección que la laptop debe usar para llegar al proxy.
    var proxyHost: String {
        switch settings.transport {
        case .usb:
            return Self.usbProxyHost
        case .wifi:
            return wifiNetwork?.addressText ?? "-"
        }
    }

    var connectionDetails: ClientConnectionDetails {
        ClientConnectionDetails(
            transport: settings.transport,
            proxyHost: proxyHost,
            port: settings.port,
            username: settings.authenticationEnabled ? settings.username : nil
        )
    }

    // MARK: - Acciones

    func refreshNetwork() {
        wifiNetwork = readWiFiNetwork()
    }

    func start() {
        guard !state.isActive else { return }
        wantsRunning = true
        startServer()
    }

    func stop() {
        wantsRunning = false
        cancelPendingRestart()
        stopServer()
        apply(.stopped)
    }

    func toggle() {
        if state.isActive {
            stop()
        } else {
            start()
        }
    }

    /// Valida y persiste los ajustes. Si el servidor estaba activo, lo reinicia con los nuevos valores.
    /// Lanza `ProxySettingsValidationError` o un error de almacenamiento.
    func save(settings newSettings: ProxySettings, password newPassword: String?) throws {
        let issues = ProxySettingsValidator.validate(newSettings, password: newPassword)
        guard issues.isEmpty else { throw ProxySettingsValidationError(issues: issues) }

        try settingsStore.saveSettings(newSettings)
        if let newPassword, !newPassword.isEmpty, newPassword != password {
            try credentialStore.savePassword(newPassword)
            password = newPassword
        }

        let wasActive = state.isActive
        let previousSettings = settings
        settings = newSettings
        startIssues = []
        if newSettings.remindsBeforeSignatureExpiry != previousSettings.remindsBeforeSignatureExpiry {
            signature.applyReminder(enabled: newSettings.remindsBeforeSignatureExpiry)
        }
        if wasActive {
            stop()
            start()
        }
    }

    func completeSetup() {
        settingsStore.hasCompletedSetup = true
        hasCompletedSetup = true
    }

    // MARK: - Servidor

    private func startServer() {
        refreshNetwork()

        let configuration: ProxyServerConfiguration
        do {
            configuration = try ProxyServerConfigurationFactory.make(from: settings, password: password)
        } catch let error as ProxySettingsValidationError {
            startIssues = error.issues
            apply(.failed(.invalidConfiguration))
            return
        } catch {
            apply(.failed(.invalidConfiguration))
            return
        }

        startIssues = []
        serverGeneration += 1
        let generation = serverGeneration
        let server = makeServer(configuration)
        server.setStateHandler { [weak self] newState in
            Task { @MainActor [weak self] in
                self?.handleServerState(newState, generation: generation)
            }
        }
        server.setStatisticsHandler { [weak self] statistics in
            Task { @MainActor [weak self] in
                guard let self, generation == self.serverGeneration else { return }
                self.activity.apply(statistics)
            }
        }
        server.setEventHandler { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, generation == self.serverGeneration else { return }
                self.activity.log(.proxy(event.kind))
            }
        }
        activity.beginSession()
        self.server = server
        server.start()
    }

    private func stopServer() {
        server?.stop()
        server = nil
        serverGeneration += 1
        activity.endSession()
    }

    private func handleServerState(_ newState: ProxyServerState, generation: Int) {
        guard generation == serverGeneration else { return }
        apply(newState)
    }

    private func apply(_ newState: ProxyServerState) {
        let previousState = state
        state = newState
        logTransition(from: previousState, to: newState)

        let isActive = newState.isActive
        let runsInBackground = isActive && settings.keepsRunningInBackground
        backgroundKeepAlive.setEnabled(runsInBackground)
        // En segundo plano no hace falta mantener la pantalla encendida.
        screenAwake.setKeepsScreenOn(isActive && !runsInBackground)
    }

    private func logTransition(from previousState: ProxyServerState, to newState: ProxyServerState) {
        switch (previousState, newState) {
        case let (.starting, .running(port, _)):
            activity.log(.serverStarted(port: port))
        case let (_, .failed(failure)) where previousState != newState:
            activity.log(.serverFailed(failure))
        case (.starting, .stopped), (.running, .stopped):
            activity.log(.serverStopped)
        default:
            break
        }
    }

    // MARK: - Cambios de red

    private func handleNetworkChange(_ availability: NetworkAvailability) {
        let previous = networkAvailability
        networkAvailability = availability
        if previous.isCellularAvailable != availability.isCellularAvailable {
            activity.log(availability.isCellularAvailable ? .cellularRestored : .cellularLost)
        }

        let previousWiFiNetwork = wifiNetwork
        refreshNetwork()

        guard wantsRunning else { return }
        if case .failed(let failure) = state, failure != .invalidConfiguration {
            if settings.transport == .usb || availability.isWiFiAvailable {
                scheduleRestart()
            }
        } else if settings.transport == .wifi, state.isActive, wifiNetwork != previousWiFiNetwork {
            // Otra red Wi-Fi u otra dirección: el listener y la lista de la laptop pueden haber cambiado.
            scheduleRestart()
        }
    }

    private func scheduleRestart() {
        cancelPendingRestart()
        restartTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.automaticRestartDelayNanoseconds)
            guard !Task.isCancelled, let self, self.wantsRunning else { return }
            self.activity.log(.automaticRestart)
            self.stopServer()
            self.startServer()
        }
    }

    private func cancelPendingRestart() {
        restartTask?.cancel()
        restartTask = nil
    }
}
