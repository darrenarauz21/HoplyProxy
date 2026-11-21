/// Cómo se conecta la laptop al iPhone.
public enum TransportMode: String, Codable, CaseIterable, Sendable {
    case usb
    case wifi
}

/// Ajustes editables por el usuario. La contraseña no forma parte del modelo:
/// se guarda en el Keychain mediante `CredentialStore`.
public struct ProxySettings: Codable, Equatable, Sendable {
    public var transport: TransportMode
    public var port: UInt16
    public var authenticationEnabled: Bool
    public var username: String
    /// Direcciones o rangos CIDR autorizados en modo Wi-Fi.
    public var allowedClients: [String]
    public var maximumConnections: Int
    public var idleTimeoutSeconds: Int
    /// Mantiene la app activa con la pantalla bloqueada mediante audio en silencio. Experimental.
    public var keepsRunningInBackground: Bool
    /// Programa una notificación local antes de que caduque la firma de la app.
    public var remindsBeforeSignatureExpiry: Bool

    public static let `default` = ProxySettings(
        transport: .usb,
        port: 1080,
        authenticationEnabled: false,
        username: "",
        allowedClients: [],
        maximumConnections: 64,
        idleTimeoutSeconds: 300,
        keepsRunningInBackground: false,
        remindsBeforeSignatureExpiry: false
    )

    public init(
        transport: TransportMode,
        port: UInt16,
        authenticationEnabled: Bool,
        username: String,
        allowedClients: [String],
        maximumConnections: Int,
        idleTimeoutSeconds: Int,
        keepsRunningInBackground: Bool,
        remindsBeforeSignatureExpiry: Bool
    ) {
        self.transport = transport
        self.port = port
        self.authenticationEnabled = authenticationEnabled
        self.username = username
        self.allowedClients = allowedClients
        self.maximumConnections = maximumConnections
        self.idleTimeoutSeconds = idleTimeoutSeconds
        self.keepsRunningInBackground = keepsRunningInBackground
        self.remindsBeforeSignatureExpiry = remindsBeforeSignatureExpiry
    }

    private enum CodingKeys: String, CodingKey {
        case transport, port, authenticationEnabled, username, allowedClients, maximumConnections, idleTimeoutSeconds
        case keepsRunningInBackground, remindsBeforeSignatureExpiry
    }

    /// Los campos ausentes toman el valor por defecto, para que versiones futuras
    /// puedan añadir ajustes sin invalidar los ya guardados.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = ProxySettings.default
        transport = try container.decodeIfPresent(TransportMode.self, forKey: .transport) ?? fallback.transport
        port = try container.decodeIfPresent(UInt16.self, forKey: .port) ?? fallback.port
        authenticationEnabled = try container.decodeIfPresent(Bool.self, forKey: .authenticationEnabled)
            ?? fallback.authenticationEnabled
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? fallback.username
        allowedClients = try container.decodeIfPresent([String].self, forKey: .allowedClients) ?? fallback.allowedClients
        maximumConnections = try container.decodeIfPresent(Int.self, forKey: .maximumConnections)
            ?? fallback.maximumConnections
        idleTimeoutSeconds = try container.decodeIfPresent(Int.self, forKey: .idleTimeoutSeconds)
            ?? fallback.idleTimeoutSeconds
        keepsRunningInBackground = try container.decodeIfPresent(Bool.self, forKey: .keepsRunningInBackground)
            ?? fallback.keepsRunningInBackground
        remindsBeforeSignatureExpiry = try container.decodeIfPresent(Bool.self, forKey: .remindsBeforeSignatureExpiry)
            ?? fallback.remindsBeforeSignatureExpiry
    }
}
