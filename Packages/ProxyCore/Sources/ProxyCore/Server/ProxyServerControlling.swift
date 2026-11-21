/// Interfaz pública del servidor; permite sustituirlo en pruebas de la capa de presentación.
/// Todos los receptores se invocan en una cola interna, no en el hilo principal.
public protocol ProxyServerControlling: AnyObject, Sendable {
    /// Registra el receptor de cambios de estado y le entrega el estado actual.
    func setStateHandler(_ handler: @escaping @Sendable (ProxyServerState) -> Void)
    /// Recibe las estadísticas acumuladas una vez por intervalo mientras el servidor está activo.
    func setStatisticsHandler(_ handler: @escaping @Sendable (ProxyTrafficStatistics) -> Void)
    /// Recibe los sucesos de diagnóstico.
    func setEventHandler(_ handler: @escaping @Sendable (ProxyEvent) -> Void)
    func start()
    func stop()
}
