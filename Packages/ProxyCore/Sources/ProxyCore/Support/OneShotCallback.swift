/// Invoca un callback como máximo una vez; las llamadas posteriores se ignoran.
/// No es seguro entre hilos: debe usarse siempre desde la misma cola serial.
final class OneShotCallback<Value>: @unchecked Sendable {
    private var handler: ((Value) -> Void)?

    init(_ handler: @escaping (Value) -> Void) {
        self.handler = handler
    }

    func callAsFunction(_ value: Value) {
        guard let handler else { return }
        self.handler = nil
        handler(value)
    }
}
