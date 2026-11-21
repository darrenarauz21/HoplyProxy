import Foundation
import Network

/// Eventos que un transporte de entrada comunica al servidor.
enum InboundTransportEvent {
    case ready(port: UInt16)
    case failed(ProxyServerFailure)
    case newConnection(NWConnection)
}

/// Origen de las conexiones de la laptop (USB, red local u otros en el futuro).
protocol InboundTransport: AnyObject {
    var eventHandler: ((InboundTransportEvent) -> Void)? { get set }
    /// Los eventos se entregan en `queue`.
    func start(port: UInt16, queue: DispatchQueue)
    func stop()
}
