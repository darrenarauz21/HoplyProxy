/// Resultado de un análisis incremental: los datos llegan por fragmentos desde la red.
public enum Socks5ParseResult<Value> {
    /// El buffer todavía no contiene el mensaje completo.
    case needMoreData
    /// Mensaje completo y cantidad de bytes del buffer que ocupaba.
    case complete(Value, consumed: Int)
}

extension Socks5ParseResult: Equatable where Value: Equatable {}
