import Foundation
import Network
import Socks5

/// Atiende una conexión de la laptop. Según el primer byte negocia SOCKS5 (con o sin
/// autenticación) o atiende una solicitud HTTP: túnel `CONNECT`, reenvío de una URL absoluta
/// o el archivo PAC. Todo el estado se accede desde la cola del servidor.
final class ConnectionSession {
    private enum Phase {
        case awaitingGreeting
        case awaitingAuthentication
        case awaitingRequest
        case awaitingHttpRequest
        case connecting(ClientProtocol)
        case relaying
        case rejecting
        case closed
    }

    /// Protocolo con el que el cliente pidió la conexión; decide cómo se le responde.
    private enum ClientProtocol {
        case socks5
        case httpTunnel
        case httpForward
    }

    /// Tiempo máximo para completar la negociación o la cabecera HTTP.
    static let handshakeTimeout: TimeInterval = 10
    /// Límite del buffer de negociación; admite cabeceras HTTP con cookies habituales.
    static let maximumHandshakeBytes = 16 * 1024

    let id = UUID()

    private let client: NWConnection
    private let connector: OutboundConnector
    private let configuration: ProxyServerConfiguration
    private let queue: DispatchQueue
    private let activity: ProxyActivityRecorder
    private let credentialVerifier: CredentialVerifier?
    private var phase = Phase.awaitingGreeting
    private var buffer: [UInt8] = []
    private var handshakeTimer: DispatchSourceTimer?
    private var relay: BidirectionalRelay?
    private var closeHandler: ((UUID) -> Void)?

    init(
        client: NWConnection,
        connector: OutboundConnector,
        configuration: ProxyServerConfiguration,
        queue: DispatchQueue,
        activity: ProxyActivityRecorder
    ) {
        self.client = client
        self.connector = connector
        self.configuration = configuration
        self.queue = queue
        self.activity = activity
        self.credentialVerifier = configuration.credentials.map { CredentialVerifier(credentials: $0) }
    }

    deinit {
        handshakeTimer?.cancel()
    }

    func start(onClose: @escaping (UUID) -> Void) {
        closeHandler = onClose
        client.stateUpdateHandler = { [weak self] state in
            self?.handleClientState(state)
        }
        startHandshakeTimer()
        client.start(queue: queue)
    }

    func close() {
        if case .closed = phase { return }
        phase = .closed
        cancelHandshakeTimer()

        let activeRelay = relay
        relay = nil
        activeRelay?.close()

        client.stateUpdateHandler = nil
        client.cancel()

        let handler = closeHandler
        closeHandler = nil
        handler?(id)
    }

    // MARK: - Recepción

    private var isAwaitingHandshakeInput: Bool {
        switch phase {
        case .awaitingGreeting, .awaitingAuthentication, .awaitingRequest, .awaitingHttpRequest:
            return true
        case .connecting, .relaying, .rejecting, .closed:
            return false
        }
    }

    /// Con credenciales configuradas no se acepta el acceso sin autenticación.
    private var supportedMethods: [Socks5AuthMethod] {
        credentialVerifier == nil ? [.noAuthentication] : [.usernamePassword]
    }

    private func handleClientState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            receiveHandshakeData()
        case .waiting, .failed, .cancelled:
            close()
        default:
            break
        }
    }

    private func receiveHandshakeData() {
        client.receive(minimumIncompleteLength: 1, maximumLength: Self.maximumHandshakeBytes) { [weak self] data, _, isComplete, error in
            guard let self, self.isAwaitingHandshakeInput else { return }

            if let data, !data.isEmpty {
                self.buffer.append(contentsOf: data)
                guard self.buffer.count <= Self.maximumHandshakeBytes else {
                    self.close()
                    return
                }
                self.advanceHandshake()
            }

            guard self.isAwaitingHandshakeInput else { return }
            if isComplete || error != nil {
                self.close()
                return
            }
            self.receiveHandshakeData()
        }
    }

    // MARK: - Negociación

    /// Procesa todo lo que el buffer permita; el cliente puede enviar varios mensajes juntos.
    private func advanceHandshake() {
        do {
            while true {
                switch phase {
                case .awaitingGreeting:
                    guard let firstByte = buffer.first else { return }
                    guard firstByte == Socks5Constants.version else {
                        guard HttpRequestHead.isPossibleRequestStart(firstByte) else {
                            close()
                            return
                        }
                        phase = .awaitingHttpRequest
                        continue
                    }
                    guard case let .complete(greeting, consumed) = try Socks5Greeting.parse(buffer) else { return }
                    buffer.removeFirst(consumed)
                    guard handleGreeting(greeting) else { return }

                case .awaitingAuthentication:
                    guard case let .complete(credentials, consumed) = try Socks5UserPassRequest.parse(buffer) else { return }
                    buffer.removeFirst(consumed)
                    guard handleAuthentication(credentials) else { return }

                case .awaitingRequest:
                    guard case let .complete(request, consumed) = try Socks5Request.parse(buffer) else { return }
                    buffer.removeFirst(consumed)
                    guard request.command == .connect else {
                        sendAndClose(Socks5ResponseEncoder.reply(.commandNotSupported))
                        return
                    }
                    connect(to: request.destination, using: .socks5)
                    return

                case .awaitingHttpRequest:
                    guard let head = try HttpRequestHead.parse(buffer) else { return }
                    buffer.removeFirst(head.byteCount)
                    try handleHttpRequest(head)
                    return

                case .connecting, .relaying, .rejecting, .closed:
                    return
                }
            }
        } catch let error as Socks5ProtocolError {
            if case .awaitingRequest = phase {
                sendAndClose(Socks5ResponseEncoder.reply(error.replyCode))
            } else {
                close()
            }
        } catch is HttpRequestError {
            sendAndClose(HttpResponse.badRequest())
        } catch {
            close()
        }
    }

    /// Devuelve `true` si la negociación continúa.
    private func handleGreeting(_ greeting: Socks5Greeting) -> Bool {
        let method = greeting.selectMethod(preferredOrder: supportedMethods)
        switch method {
        case .noAcceptableMethods:
            sendAndClose(Socks5ResponseEncoder.methodSelection(method))
            return false
        case .usernamePassword:
            send(Socks5ResponseEncoder.methodSelection(method))
            phase = .awaitingAuthentication
            return true
        case .noAuthentication:
            send(Socks5ResponseEncoder.methodSelection(method))
            phase = .awaitingRequest
            return true
        }
    }

    /// Devuelve `true` si las credenciales son válidas. Un fallo cierra la conexión.
    private func handleAuthentication(_ credentials: Socks5UserPassRequest) -> Bool {
        let isValid = credentialVerifier?.verify(username: credentials.username, password: credentials.password) ?? false
        guard isValid else {
            activity.recordAuthenticationFailure(from: client.endpoint)
            sendAndClose(Socks5ResponseEncoder.authenticationStatus(succeeded: false))
            return false
        }
        send(Socks5ResponseEncoder.authenticationStatus(succeeded: true))
        phase = .awaitingRequest
        return true
    }

    // MARK: - HTTP

    private func handleHttpRequest(_ head: HttpRequestHead) throws {
        let route = try HttpProxyRoute.resolve(head)

        // El archivo PAC se sirve sin credenciales: el sistema operativo lo descarga sin pedirlas.
        if case .localResource = route {
            sendAndClose(PacHttpResponse.response(for: head, proxyHost: pacProxyHost, port: configuration.port))
            return
        }

        guard isAuthorized(head) else {
            if head.value(forHeader: "Proxy-Authorization") != nil {
                activity.recordAuthenticationFailure(from: client.endpoint)
            }
            sendAndClose(HttpProxyResponse.authenticationRequired())
            return
        }

        switch route {
        case .localResource:
            return
        case .tunnel(let destination):
            connect(to: destination, using: .httpTunnel)
        case let .forward(destination, authority, originTarget):
            // La solicitud reescrita va antes de cualquier cuerpo que ya haya llegado.
            buffer = HttpForwardRequest.make(from: head, authority: authority, originTarget: originTarget) + buffer
            connect(to: destination, using: .httpForward)
        }
    }

    private func isAuthorized(_ head: HttpRequestHead) -> Bool {
        guard let credentialVerifier else { return true }
        guard let headerValue = head.value(forHeader: "Proxy-Authorization"),
              let authorization = HttpProxyAuthorization.parse(headerValue) else { return false }
        return credentialVerifier.verify(username: authorization.username, password: authorization.password)
    }

    /// Dirección del iPhone tal como la ve la laptop: 127.0.0.1 por USB o la IP Wi-Fi.
    private var pacProxyHost: String {
        if case let .hostPort(host, _)? = client.currentPath?.localEndpoint, let address = host.ipv4Value {
            return IPv4Subnet.formatAddress(address)
        }
        return "127.0.0.1"
    }

    // MARK: - Conexión de salida

    private func connect(to destination: Socks5Destination, using clientProtocol: ClientProtocol) {
        phase = .connecting(clientProtocol)
        cancelHandshakeTimer()

        connector.connect(to: destination, queue: queue) { [weak self] result in
            guard let self, case .connecting = self.phase else {
                if case let .success(remote) = result { remote.cancel() }
                return
            }
            switch result {
            case .success(let remote):
                self.startRelay(with: remote, reply: Self.successReply(for: clientProtocol))
            case .failure(let error):
                self.activity.recordOutboundFailure(error)
                self.sendAndClose(Self.failureReply(for: clientProtocol, error: error))
            }
        }
    }

    private static func successReply(for clientProtocol: ClientProtocol) -> [UInt8] {
        switch clientProtocol {
        case .socks5:
            return Socks5ResponseEncoder.reply(.succeeded)
        case .httpTunnel:
            return HttpProxyResponse.connectionEstablished()
        case .httpForward:
            // La respuesta la envía el servidor de destino.
            return []
        }
    }

    private static func failureReply(for clientProtocol: ClientProtocol, error: OutboundConnectionError) -> [UInt8] {
        switch clientProtocol {
        case .socks5:
            return Socks5ResponseEncoder.reply(error.replyCode)
        case .httpTunnel, .httpForward:
            return HttpProxyResponse.failure(for: error)
        }
    }

    private func startRelay(with remote: NWConnection, reply: [UInt8]) {
        phase = .relaying
        guard !reply.isEmpty else {
            beginRelay(with: remote)
            return
        }
        client.send(content: Data(reply), completion: .contentProcessed { [weak self] error in
            guard let self, case .relaying = self.phase, error == nil else {
                remote.cancel()
                self?.close()
                return
            }
            self.beginRelay(with: remote)
        })
    }

    private func beginRelay(with remote: NWConnection) {
        let relay = BidirectionalRelay(
            client: client,
            remote: remote,
            pendingClientBytes: buffer,
            queue: queue,
            idleTimeout: configuration.idleTimeout
        ) { [weak activity = self.activity] byteCount, direction in
            activity?.recordTransfer(byteCount, direction: direction)
        }
        buffer = []
        self.relay = relay
        relay.start { [weak self] in
            self?.close()
        }
    }

    // MARK: - Envío

    private func send(_ bytes: [UInt8]) {
        client.send(content: Data(bytes), completion: .contentProcessed { [weak self] error in
            guard error != nil else { return }
            self?.close()
        })
    }

    /// Envía una respuesta final y cierra cuando termina de transmitirse.
    private func sendAndClose(_ bytes: [UInt8]) {
        phase = .rejecting
        cancelHandshakeTimer()
        client.send(content: Data(bytes), completion: .contentProcessed { [weak self] _ in
            self?.close()
        })
    }

    // MARK: - Temporizador

    private func startHandshakeTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.setEventHandler { [weak self] in
            guard let self, self.isAwaitingHandshakeInput else { return }
            self.close()
        }
        timer.schedule(deadline: .now() + Self.handshakeTimeout)
        timer.resume()
        handshakeTimer = timer
    }

    private func cancelHandshakeTimer() {
        handshakeTimer?.cancel()
        handshakeTimer = nil
    }
}
