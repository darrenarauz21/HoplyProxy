import ProxyConfig
import ProxyCore

/// Punto único de composición: crea las dependencias concretas e inyecta las abstracciones.
@MainActor
enum AppContainer {
    /// Fijo para que la contraseña sobreviva a reinstalaciones con otro identificador de app.
    private static let keychainService = "Hoply.credentials"

    static func makeProxyController() -> ProxyController {
        ProxyController(
            settingsStore: UserDefaultsProxySettingsStore(),
            credentialStore: KeychainCredentialStore(service: keychainService),
            makeServer: { configuration in ProxyServer(configuration: configuration) },
            readWiFiNetwork: { WiFiInterfaceReader.currentNetwork() },
            screenAwake: ScreenAwakeController(),
            backgroundKeepAlive: BackgroundKeepAliveController(),
            networkMonitor: NetworkAvailabilityMonitor(),
            activity: ProxyActivityStore(),
            signature: SignatureMonitor(
                expirationDate: SignatureExpirationReader.expirationDate(),
                scheduler: RenewalReminderScheduler()
            )
        )
    }
}
