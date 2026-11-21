import Foundation
import Network

/// Transporte basado en `NWListener`; la interfaz donde escucha la define `makeListener`.
final class NetworkListenerTransport: InboundTransport {
    var eventHandler: ((InboundTransportEvent) -> Void)?

    private let makeListener: (NWEndpoint.Port) throws -> NWListener
    private var listener: NWListener?

    init(makeListener: @escaping (NWEndpoint.Port) throws -> NWListener) {
        self.makeListener = makeListener
    }

    /// Escucha solo en 127.0.0.1 del iPhone. El reenvío de usbmuxd entrega ahí las conexiones
    /// que llegan por USB, y ningún otro equipo de la red puede alcanzar el puerto.
    static func loopback() -> NetworkListenerTransport {
        NetworkListenerTransport { port in
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: port)
            return try NWListener(using: parameters)
        }
    }

    /// Escucha solo en la interfaz Wi-Fi, nunca en la de datos móviles. Las conexiones aceptadas
    /// heredan el keepalive de TCP, que detecta laptops que salieron de la red sin cerrar.
    static func wifi() -> NetworkListenerTransport {
        NetworkListenerTransport { port in
            let parameters = NWParameters(tls: nil, tcp: .withKeepAlive())
            parameters.allowLocalEndpointReuse = true
            parameters.requiredInterfaceType = .wifi
            parameters.prohibitedInterfaceTypes = [.cellular]
            return try NWListener(using: parameters, on: port)
        }
    }

    static func make(for scope: ListenScope) -> NetworkListenerTransport {
        switch scope {
        case .loopback:
            return loopback()
        case .wifi:
            return wifi()
        }
    }

    func start(port: UInt16, queue: DispatchQueue) {
        guard listener == nil else { return }
        guard let listenPort = NWEndpoint.Port(rawValue: port) else {
            eventHandler?(.failed(.invalidConfiguration))
            return
        }

        let listener: NWListener
        do {
            listener = try makeListener(listenPort)
        } catch {
            eventHandler?(.failed(.listenerFailed))
            return
        }

        listener.stateUpdateHandler = { [weak self] state in
            self?.handleStateChange(state, port: port)
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else {
                connection.cancel()
                return
            }
            self.eventHandler?(.newConnection(connection))
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    func stop() {
        guard let listener else { return }
        listener.stateUpdateHandler = nil
        listener.newConnectionHandler = nil
        listener.cancel()
        self.listener = nil
    }

    private func handleStateChange(_ state: NWListener.State, port: UInt16) {
        switch state {
        case .ready:
            eventHandler?(.ready(port: listener?.port?.rawValue ?? port))
        case .failed(let error):
            stop()
            eventHandler?(.failed(Self.failure(for: error, port: port, isWaiting: false)))
        case .waiting(let error):
            stop()
            eventHandler?(.failed(Self.failure(for: error, port: port, isWaiting: true)))
        case .setup, .cancelled:
            break
        @unknown default:
            break
        }
    }

    /// Valor de `kDNSServiceErr_PolicyDenied`: el usuario negó el permiso de red local.
    private static let policyDeniedError: Int32 = -65570

    private static func failure(for error: NWError, port: UInt16, isWaiting: Bool) -> ProxyServerFailure {
        switch error {
        case .posix(.EADDRINUSE):
            return .portUnavailable(port)
        case .dns(let code) where code == policyDeniedError:
            return .localNetworkDenied
        default:
            // Un listener en espera indica que la interfaz requerida (por ejemplo, Wi-Fi) no está disponible.
            return isWaiting ? .networkUnavailable : .listenerFailed
        }
    }
}
