import Network

extension NWProtocolTCP.Options {
    /// Segundos sin tráfico antes de enviar la primera sonda.
    static let keepAliveIdleSeconds = 60
    /// Segundos entre sondas sin respuesta.
    static let keepAliveIntervalSeconds = 15
    /// Sondas sin respuesta tras las que la conexión se da por perdida.
    static let keepAliveProbeCount = 4

    /// Opciones de TCP con keepalive: mantiene vivas las conexiones inactivas ante NAT y
    /// operadores que descartan sesiones sin tráfico, y detecta extremos desaparecidos.
    static func withKeepAlive() -> NWProtocolTCP.Options {
        let options = NWProtocolTCP.Options()
        options.enableKeepalive = true
        options.keepaliveIdle = keepAliveIdleSeconds
        options.keepaliveInterval = keepAliveIntervalSeconds
        options.keepaliveCount = keepAliveProbeCount
        return options
    }
}
