import Foundation
import Network

/// Copia bytes entre la laptop y el destino en ambos sentidos.
/// Solo se pide el siguiente fragmento cuando el anterior terminó de enviarse, lo que limita
/// la memoria usada por conexión aunque un extremo sea mucho más rápido que el otro.
final class BidirectionalRelay {
    private typealias Direction = TrafficDirection

    /// Recibe cada fragmento entregado: bytes y sentido.
    typealias TransferObserver = (Int, TrafficDirection) -> Void

    static let chunkSize = 64 * 1024

    private let client: NWConnection
    private let remote: NWConnection
    private let queue: DispatchQueue
    private let idleTimeout: TimeInterval
    private let transferObserver: TransferObserver
    private var pendingClientBytes: [UInt8]
    private var finishedDirections: Set<Direction> = []
    private var idleTimer: DispatchSourceTimer?
    private var closeHandler: (() -> Void)?
    private var isClosed = false

    /// `pendingClientBytes` son datos que deben llegar al destino antes que el resto: lo que la laptop
    /// envió junto con la solicitud o, en el reenvío HTTP, la solicitud reescrita.
    init(
        client: NWConnection,
        remote: NWConnection,
        pendingClientBytes: [UInt8],
        queue: DispatchQueue,
        idleTimeout: TimeInterval,
        transferObserver: @escaping TransferObserver = { _, _ in }
    ) {
        self.client = client
        self.remote = remote
        self.pendingClientBytes = pendingClientBytes
        self.queue = queue
        self.idleTimeout = idleTimeout
        self.transferObserver = transferObserver
    }

    deinit {
        idleTimer?.cancel()
    }

    func start(onClose: @escaping () -> Void) {
        closeHandler = onClose
        client.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionState(state)
        }
        remote.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionState(state)
        }
        startIdleTimer()
        forwardPendingClientBytes()
        pump(.downstream)
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        idleTimer?.cancel()
        idleTimer = nil
        client.stateUpdateHandler = nil
        remote.stateUpdateHandler = nil
        client.cancel()
        remote.cancel()

        let handler = closeHandler
        closeHandler = nil
        handler?()
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        // `waiting` en una conexión establecida indica que se perdió la ruta (por ejemplo, la señal):
        // se cierra para que el cliente reintente en lugar de esperar al cierre por inactividad.
        case .waiting, .failed, .cancelled:
            close()
        default:
            break
        }
    }

    private func forwardPendingClientBytes() {
        guard !pendingClientBytes.isEmpty else {
            pump(.upstream)
            return
        }
        let data = Data(pendingClientBytes)
        pendingClientBytes = []
        transferObserver(data.count, .upstream)

        remote.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self, !self.isClosed else { return }
            guard error == nil else {
                self.close()
                return
            }
            self.pump(.upstream)
        })
    }

    private func pump(_ direction: Direction) {
        let source = self.source(for: direction)
        let destination = self.destination(for: direction)

        source.receive(minimumIncompleteLength: 1, maximumLength: Self.chunkSize) { [weak self] data, _, isComplete, error in
            guard let self, !self.isClosed else { return }

            if let data, !data.isEmpty {
                self.resetIdleTimer()
                self.transferObserver(data.count, direction)
                destination.send(content: data, completion: .contentProcessed { [weak self] sendError in
                    guard let self, !self.isClosed else { return }
                    guard sendError == nil else {
                        self.close()
                        return
                    }
                    if isComplete {
                        self.finish(direction)
                    } else {
                        self.pump(direction)
                    }
                })
                return
            }

            if isComplete {
                self.finish(direction)
            } else if error != nil {
                self.close()
            } else {
                self.pump(direction)
            }
        }
    }

    /// Un extremo terminó de enviar: se propaga el cierre de escritura al otro (half-close de TCP)
    /// y la sesión termina cuando ambos sentidos han finalizado.
    private func finish(_ direction: Direction) {
        finishedDirections.insert(direction)
        guard finishedDirections.count < 2 else {
            close()
            return
        }
        destination(for: direction).send(
            content: nil,
            contentContext: .finalMessage,
            isComplete: true,
            completion: .contentProcessed { [weak self] error in
                guard error != nil else { return }
                self?.close()
            }
        )
    }

    private func source(for direction: Direction) -> NWConnection {
        direction == .upstream ? client : remote
    }

    private func destination(for direction: Direction) -> NWConnection {
        direction == .upstream ? remote : client
    }

    private func startIdleTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.setEventHandler { [weak self] in
            self?.close()
        }
        timer.schedule(deadline: .now() + idleTimeout)
        timer.resume()
        idleTimer = timer
    }

    private func resetIdleTimer() {
        idleTimer?.schedule(deadline: .now() + idleTimeout)
    }
}
