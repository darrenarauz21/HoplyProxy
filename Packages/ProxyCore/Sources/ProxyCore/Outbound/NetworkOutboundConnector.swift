import Foundation
import Network
import Socks5

/// Conector basado en `NWConnection`; la política de red la define `makeParameters`.
final class NetworkOutboundConnector: OutboundConnector {
    private let makeParameters: () -> NWParameters

    init(makeParameters: @escaping () -> NWParameters) {
        self.makeParameters = makeParameters
    }

    /// Obliga a que la conexión y la resolución DNS usen la interfaz de datos móviles,
    /// aunque el iPhone esté conectado a una red Wi-Fi.
    static func cellular(connectTimeout: Int) -> NetworkOutboundConnector {
        NetworkOutboundConnector {
            let tcpOptions = NWProtocolTCP.Options.withKeepAlive()
            tcpOptions.connectionTimeout = connectTimeout
            tcpOptions.noDelay = true
            let parameters = NWParameters(tls: nil, tcp: tcpOptions)
            parameters.requiredInterfaceType = .cellular
            return parameters
        }
    }

    func connect(
        to destination: Socks5Destination,
        queue: DispatchQueue,
        completion: @escaping (Result<NWConnection, OutboundConnectionError>) -> Void
    ) {
        guard let endpoint = destination.networkEndpoint else {
            completion(.failure(.invalidDestination))
            return
        }

        let connection = NWConnection(to: endpoint, using: makeParameters())
        let finish = OneShotCallback<Result<NWConnection, OutboundConnectionError>> { result in
            connection.stateUpdateHandler = nil
            completion(result)
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(.success(connection))
            case .waiting(let error):
                // Sin ruta disponible (por ejemplo, sin datos móviles) o conexión rechazada:
                // se informa al cliente en lugar de esperar indefinidamente.
                connection.cancel()
                finish(.failure(OutboundConnectionError(error)))
            case .failed(let error):
                connection.cancel()
                finish(.failure(OutboundConnectionError(error)))
            case .cancelled:
                finish(.failure(.failed))
            case .setup, .preparing:
                break
            @unknown default:
                break
            }
        }
        connection.start(queue: queue)
    }
}
