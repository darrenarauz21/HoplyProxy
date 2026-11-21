import Foundation
import Network

/// Servidor TCP local que devuelve todo lo que recibe.
final class EchoServer {
    private let listener: NWListener
    private var connections: [NWConnection] = []

    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
    }

    func start(queue: DispatchQueue, onReady: @escaping (UInt16) -> Void) {
        listener.stateUpdateHandler = { [weak self] state in
            guard case .ready = state, let port = self?.listener.port else { return }
            onReady(port.rawValue)
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.connections.append(connection)
            connection.start(queue: queue)
            self?.echo(on: connection)
        }
        listener.start(queue: queue)
    }

    func stop() {
        listener.cancel()
        connections.forEach { $0.cancel() }
    }

    private func echo(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            if let data, !data.isEmpty {
                connection.send(content: data, completion: .contentProcessed { _ in })
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self?.echo(on: connection)
        }
    }
}
