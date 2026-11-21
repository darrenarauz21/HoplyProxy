import Foundation

/// Dónde escucha el servidor dentro del iPhone.
public enum ListenScope: Equatable, Sendable {
    /// Solo 127.0.0.1: conexiones que llegan por USB mediante usbmuxd.
    case loopback
    /// Interfaz Wi-Fi: equipos de la misma red local incluidos en la lista de clientes.
    case wifi
}

/// Credenciales SOCKS5 usuario/contraseña exigidas a los clientes.
public struct ProxyCredentials: Equatable, Sendable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

/// Parámetros de funcionamiento del servidor.
public struct ProxyServerConfiguration: Equatable, Sendable {
    public static let portRange: ClosedRange<UInt16> = 1024...65535
    public static let maximumConnectionsRange: ClosedRange<Int> = 1...512
    public static let idleTimeoutRange: ClosedRange<TimeInterval> = 10...3600
    public static let connectTimeoutRange: ClosedRange<Int> = 1...120
    /// Límite de bytes de RFC 1929 para usuario y contraseña.
    public static let credentialByteRange: ClosedRange<Int> = 1...255

    public static let `default` = ProxyServerConfiguration(
        port: 1080,
        maximumConnections: 64,
        idleTimeout: 300,
        connectTimeout: 15
    )

    /// Puerto TCP en el que escucha el servidor dentro del iPhone.
    public var port: UInt16
    /// Conexiones simultáneas aceptadas; las adicionales se rechazan.
    public var maximumConnections: Int
    /// Segundos sin tráfico tras los que se cierra una conexión.
    public var idleTimeout: TimeInterval
    /// Segundos máximos para establecer la conexión con el destino.
    public var connectTimeout: Int
    public var listenScope: ListenScope
    /// `nil` desactiva la autenticación.
    public var credentials: ProxyCredentials?
    /// Obligatoria en Wi-Fi; se ignora en loopback.
    public var allowedClients: [IPv4Subnet]

    public init(
        port: UInt16,
        maximumConnections: Int,
        idleTimeout: TimeInterval,
        connectTimeout: Int,
        listenScope: ListenScope = .loopback,
        credentials: ProxyCredentials? = nil,
        allowedClients: [IPv4Subnet] = []
    ) {
        self.port = port
        self.maximumConnections = maximumConnections
        self.idleTimeout = idleTimeout
        self.connectTimeout = connectTimeout
        self.listenScope = listenScope
        self.credentials = credentials
        self.allowedClients = allowedClients
    }

    public var isValid: Bool {
        Self.portRange.contains(port)
            && Self.maximumConnectionsRange.contains(maximumConnections)
            && Self.idleTimeoutRange.contains(idleTimeout)
            && Self.connectTimeoutRange.contains(connectTimeout)
            && hasValidCredentials
            && hasValidAccessList
    }

    private var hasValidCredentials: Bool {
        guard let credentials else { return true }
        return Self.credentialByteRange.contains(credentials.username.utf8.count)
            && Self.credentialByteRange.contains(credentials.password.utf8.count)
    }

    private var hasValidAccessList: Bool {
        listenScope == .loopback || !allowedClients.isEmpty
    }
}
