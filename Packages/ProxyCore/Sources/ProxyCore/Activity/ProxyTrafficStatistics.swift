/// Contadores acumulados desde que el servidor inició.
public struct ProxyTrafficStatistics: Equatable, Sendable {
    /// Bytes enviados por la laptop hacia internet.
    public var bytesUploaded: UInt64
    /// Bytes recibidos de internet y entregados a la laptop.
    public var bytesDownloaded: UInt64
    /// Conexiones de la laptop aceptadas por el servidor.
    public var acceptedConnections: Int
    /// Conexiones descartadas por no estar autorizadas o por superar el límite.
    public var rejectedConnections: Int
    /// Conexiones cuyo destino no se pudo alcanzar.
    public var failedConnections: Int

    public static let zero = ProxyTrafficStatistics(
        bytesUploaded: 0,
        bytesDownloaded: 0,
        acceptedConnections: 0,
        rejectedConnections: 0,
        failedConnections: 0
    )

    public init(
        bytesUploaded: UInt64,
        bytesDownloaded: UInt64,
        acceptedConnections: Int,
        rejectedConnections: Int,
        failedConnections: Int
    ) {
        self.bytesUploaded = bytesUploaded
        self.bytesDownloaded = bytesDownloaded
        self.acceptedConnections = acceptedConnections
        self.rejectedConnections = rejectedConnections
        self.failedConnections = failedConnections
    }
}

/// Sentido del tráfico dentro de una conexión retransmitida.
enum TrafficDirection: Hashable {
    /// Laptop hacia destino.
    case upstream
    /// Destino hacia laptop.
    case downstream
}
