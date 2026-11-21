import Foundation
import Network
@testable import ProxyCore

/// Cliente mínimo para ejercitar el servidor mensaje a mensaje.
final class Socks5TestClient {
    static let greetingNoAuth: [UInt8] = [0x05, 0x01, 0x00]
    static let methodSelectionLength = 2
    static let replyLength = 10

    private let connection: NWConnection

    init(proxyPort: UInt16, queue: DispatchQueue) {
        connection = NWConnection(
            host: "127.0.0.1",
            port: NWEndpoint.Port(rawValue: proxyPort) ?? .any,
            using: .tcp
        )
        connection.start(queue: queue)
    }

    /// Solicitud SOCKS5 hacia 127.0.0.1 en el puerto indicado.
    static func loopbackRequest(command: UInt8, port: UInt16) -> [UInt8] {
        [0x05, command, 0x00, 0x01, 127, 0, 0, 1, UInt8(port >> 8), UInt8(port & 0xFF)]
    }

    /// Mensaje de autenticación RFC 1929.
    static func userPass(_ credentials: ProxyCredentials) -> [UInt8] {
        let username = Array(credentials.username.utf8)
        let password = Array(credentials.password.utf8)
        return [0x01, UInt8(username.count)] + username + [UInt8(password.count)] + password
    }

    /// Envía `bytes` y acumula la respuesta hasta que el servidor cierra la conexión.
    func sendAndReadUntilClose(_ bytes: [UInt8], completion: @escaping ([UInt8]) -> Void) {
        connection.send(content: Data(bytes), completion: .contentProcessed { [weak self] _ in
            self?.readUntilClose(accumulated: [], completion: completion)
        })
    }

    private func readUntilClose(accumulated: [UInt8], completion: @escaping ([UInt8]) -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            let total = accumulated + (data.map { Array($0) } ?? [])
            if isComplete || error != nil || self == nil {
                completion(total)
            } else {
                self?.readUntilClose(accumulated: total, completion: completion)
            }
        }
    }

    /// Envía `bytes` y entrega exactamente `responseLength` bytes, o `nil` si falla.
    func send(_ bytes: [UInt8], expecting responseLength: Int, completion: @escaping ([UInt8]?) -> Void) {
        connection.send(content: Data(bytes), completion: .contentProcessed { [connection = self.connection] error in
            guard error == nil else {
                completion(nil)
                return
            }
            connection.receive(minimumIncompleteLength: responseLength, maximumLength: responseLength) { data, _, _, receiveError in
                guard receiveError == nil, let data, data.count == responseLength else {
                    completion(nil)
                    return
                }
                completion(Array(data))
            }
        })
    }

    func cancel() {
        connection.cancel()
    }
}
