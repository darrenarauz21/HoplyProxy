import Foundation
import ProxyConfig

/// Borrador editable de los ajustes; solo se aplica al guardar.
@MainActor
final class SettingsViewModel: ObservableObject {
    static let idleTimeoutRange = 30...3600
    static let idleTimeoutStep = 30

    @Published var transport: TransportMode
    @Published var port: Int
    @Published private(set) var authenticationEnabled: Bool
    @Published var username: String
    @Published var password: String
    @Published var allowedClients: [String]
    @Published var newAllowedClient = ""
    @Published var maximumConnections: Int
    @Published var idleTimeoutSeconds: Int
    @Published var keepsRunningInBackground: Bool
    @Published var remindsBeforeSignatureExpiry: Bool
    @Published private(set) var issues: [ProxySettingsIssue] = []
    @Published private(set) var didFailToPersist = false

    private let controller: ProxyController

    init(controller: ProxyController) {
        self.controller = controller
        let settings = controller.settings
        transport = settings.transport
        port = Int(settings.port)
        authenticationEnabled = settings.authenticationEnabled
        username = settings.username
        password = controller.password ?? ""
        allowedClients = settings.allowedClients
        maximumConnections = settings.maximumConnections
        idleTimeoutSeconds = settings.idleTimeoutSeconds
        keepsRunningInBackground = settings.keepsRunningInBackground
        remindsBeforeSignatureExpiry = settings.remindsBeforeSignatureExpiry
    }

    var isServerActive: Bool {
        controller.state.isActive
    }

    /// El recordatorio solo tiene sentido si la app conoce la fecha de caducidad de su firma.
    var canRemindBeforeSignatureExpiry: Bool {
        controller.signature.expirationDate != nil
    }

    /// Red Wi-Fi actual del iPhone, si todavía no está en la lista.
    var suggestedSubnet: String? {
        guard let subnet = controller.wifiNetwork?.subnet.description,
              !allowedClients.contains(subnet) else { return nil }
        return subnet
    }

    var canAddAllowedClient: Bool {
        !normalizedNewAllowedClient.isEmpty
    }

    /// Al activar la autenticación por primera vez se generan credenciales seguras.
    func setAuthenticationEnabled(_ enabled: Bool) {
        authenticationEnabled = enabled
        if enabled, username.isEmpty || password.isEmpty {
            generateCredentials()
        }
    }

    func generateCredentials() {
        username = CredentialGenerator.makeUsername()
        password = CredentialGenerator.makePassword()
    }

    func addAllowedClient() {
        let entry = normalizedNewAllowedClient
        guard !entry.isEmpty, !allowedClients.contains(entry) else { return }
        allowedClients.append(entry)
        newAllowedClient = ""
    }

    func addSuggestedSubnet() {
        guard let suggestedSubnet else { return }
        allowedClients.append(suggestedSubnet)
    }

    func removeAllowedClients(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where allowedClients.indices.contains(index) {
            allowedClients.remove(at: index)
        }
    }

    func refreshNetwork() {
        controller.refreshNetwork()
        objectWillChange.send()
    }

    /// Devuelve `true` si los ajustes se guardaron.
    func save() -> Bool {
        guard let validPort = UInt16(exactly: port) else {
            issues = [.portOutOfRange]
            return false
        }

        let settings = ProxySettings(
            transport: transport,
            port: validPort,
            authenticationEnabled: authenticationEnabled,
            username: username,
            allowedClients: allowedClients,
            maximumConnections: maximumConnections,
            idleTimeoutSeconds: idleTimeoutSeconds,
            keepsRunningInBackground: keepsRunningInBackground,
            remindsBeforeSignatureExpiry: remindsBeforeSignatureExpiry
        )

        do {
            try controller.save(settings: settings, password: password.isEmpty ? nil : password)
            issues = []
            didFailToPersist = false
            return true
        } catch let error as ProxySettingsValidationError {
            issues = error.issues
            return false
        } catch {
            didFailToPersist = true
            return false
        }
    }

    private var normalizedNewAllowedClient: String {
        newAllowedClient.trimmingCharacters(in: .whitespaces)
    }
}
