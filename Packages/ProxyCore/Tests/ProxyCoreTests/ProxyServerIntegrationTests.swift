import Network
import XCTest
@testable import ProxyCore

/// Ejercita el servidor real en loopback. El conector de salida no fuerza la interfaz celular
/// para poder alcanzar el servidor de eco local.
final class ProxyServerIntegrationTests: XCTestCase {
    private let queue = DispatchQueue(label: "ProxyCoreTests")
    private let timeout: TimeInterval = 10
    private var server: ProxyServer?
    private var echoServer: EchoServer?
    private var client: Socks5TestClient?

    override func tearDown() {
        client?.cancel()
        server?.stop()
        echoServer?.stop()
        super.tearDown()
    }

    func testRelaysDataThroughConnect() throws {
        let echoPort = try startEchoServer()
        let client = makeClient(proxyPort: startProxyServer())
        let payload = Array("ping".utf8)
        let received = expectation(description: "eco recibido a través del proxy")

        client.send(Socks5TestClient.greetingNoAuth, expecting: Socks5TestClient.methodSelectionLength) { selection in
            XCTAssertEqual(selection, [0x05, 0x00])
            let request = Socks5TestClient.loopbackRequest(command: 0x01, port: echoPort)
            client.send(request, expecting: Socks5TestClient.replyLength) { reply in
                XCTAssertEqual(reply?[1], 0x00)
                client.send(payload, expecting: payload.count) { echoed in
                    XCTAssertEqual(echoed, payload)
                    received.fulfill()
                }
            }
        }
        wait(for: [received], timeout: timeout)
    }

    func testRejectsBindCommand() {
        let client = makeClient(proxyPort: startProxyServer())
        let rejected = expectation(description: "BIND rechazado")

        client.send(Socks5TestClient.greetingNoAuth, expecting: Socks5TestClient.methodSelectionLength) { _ in
            let request = Socks5TestClient.loopbackRequest(command: 0x02, port: 80)
            client.send(request, expecting: Socks5TestClient.replyLength) { reply in
                XCTAssertEqual(reply?[1], 0x07)
                rejected.fulfill()
            }
        }
        wait(for: [rejected], timeout: timeout)
    }

    func testReportsConnectionRefused() {
        let client = makeClient(proxyPort: startProxyServer())
        let refused = expectation(description: "conexión rechazada informada")

        client.send(Socks5TestClient.greetingNoAuth, expecting: Socks5TestClient.methodSelectionLength) { _ in
            let request = Socks5TestClient.loopbackRequest(command: 0x01, port: 1)
            client.send(request, expecting: Socks5TestClient.replyLength) { reply in
                XCTAssertEqual(reply?[1], 0x05)
                refused.fulfill()
            }
        }
        wait(for: [refused], timeout: timeout)
    }

    func testAuthenticatesWithValidCredentials() throws {
        let echoPort = try startEchoServer()
        let client = makeClient(proxyPort: startProxyServer(credentials: testCredentials))
        let payload = Array("hola".utf8)
        let received = expectation(description: "eco recibido con autenticación")

        client.send([0x05, 0x01, 0x02], expecting: Socks5TestClient.methodSelectionLength) { selection in
            XCTAssertEqual(selection, [0x05, 0x02])
            client.send(Socks5TestClient.userPass(self.testCredentials), expecting: 2) { status in
                XCTAssertEqual(status, [0x01, 0x00])
                let request = Socks5TestClient.loopbackRequest(command: 0x01, port: echoPort)
                client.send(request, expecting: Socks5TestClient.replyLength) { reply in
                    XCTAssertEqual(reply?[1], 0x00)
                    client.send(payload, expecting: payload.count) { echoed in
                        XCTAssertEqual(echoed, payload)
                        received.fulfill()
                    }
                }
            }
        }
        wait(for: [received], timeout: timeout)
    }

    func testRejectsInvalidCredentials() {
        let client = makeClient(proxyPort: startProxyServer(credentials: testCredentials))
        let wrong = ProxyCredentials(username: testCredentials.username, password: "incorrecta")
        let rejected = expectation(description: "credenciales rechazadas")

        client.send([0x05, 0x01, 0x02], expecting: Socks5TestClient.methodSelectionLength) { _ in
            client.send(Socks5TestClient.userPass(wrong), expecting: 2) { status in
                XCTAssertEqual(status, [0x01, 0x01])
                rejected.fulfill()
            }
        }
        wait(for: [rejected], timeout: timeout)
    }

    func testRejectsNoAuthenticationWhenCredentialsAreConfigured() {
        let client = makeClient(proxyPort: startProxyServer(credentials: testCredentials))
        let rejected = expectation(description: "acceso sin autenticación rechazado")

        client.send(Socks5TestClient.greetingNoAuth, expecting: Socks5TestClient.methodSelectionLength) { selection in
            XCTAssertEqual(selection, [0x05, 0xFF])
            rejected.fulfill()
        }
        wait(for: [rejected], timeout: timeout)
    }

    func testServesPacFileOnTheProxyPort() {
        let proxyPort = startProxyServer()
        let client = makeClient(proxyPort: proxyPort)
        let served = expectation(description: "archivo PAC servido")
        let request = Array("GET /proxy.pac HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n".utf8)

        client.sendAndReadUntilClose(request) { response in
            let text = String(decoding: response, as: UTF8.self)
            XCTAssertTrue(text.hasPrefix("HTTP/1.1 200 OK"))
            XCTAssertTrue(text.contains("application/x-ns-proxy-autoconfig"))
            XCTAssertTrue(text.contains("PROXY 127.0.0.1:\(proxyPort); SOCKS5 127.0.0.1:\(proxyPort)"))
            served.fulfill()
        }
        wait(for: [served], timeout: timeout)
    }

    func testRejectsClientWithoutSupportedMethod() {
        let client = makeClient(proxyPort: startProxyServer())
        let rejected = expectation(description: "método no aceptado")

        client.send([0x05, 0x01, 0x02], expecting: Socks5TestClient.methodSelectionLength) { selection in
            XCTAssertEqual(selection, [0x05, 0xFF])
            rejected.fulfill()
        }
        wait(for: [rejected], timeout: timeout)
    }

    // MARK: - Proxy HTTP

    func testTunnelsDataThroughHttpConnect() throws {
        let echoPort = try startEchoServer()
        let client = makeClient(proxyPort: startProxyServer())
        let established = HttpProxyResponse.connectionEstablished()
        let payload = Array("tunel".utf8)
        let received = expectation(description: "eco recibido a través de CONNECT")

        client.send(connectRequest(port: echoPort), expecting: established.count) { response in
            XCTAssertEqual(response, established)
            client.send(payload, expecting: payload.count) { echoed in
                XCTAssertEqual(echoed, payload)
                received.fulfill()
            }
        }
        wait(for: [received], timeout: timeout)
    }

    func testForwardsAbsoluteUrlWithRewrittenRequest() throws {
        let echoPort = try startEchoServer()
        let client = makeClient(proxyPort: startProxyServer())
        let request = Array((
            "GET http://127.0.0.1:\(echoPort)/hola?x=1 HTTP/1.1\r\n" +
            "Host: 127.0.0.1:\(echoPort)\r\n" +
            "Proxy-Connection: keep-alive\r\n\r\n"
        ).utf8)
        let expected = Array("GET /hola?x=1 HTTP/1.1\r\nHost: 127.0.0.1:\(echoPort)\r\nConnection: close\r\n\r\n".utf8)
        let received = expectation(description: "solicitud reescrita recibida por el destino")

        client.send(request, expecting: expected.count) { echoed in
            XCTAssertEqual(echoed, expected)
            received.fulfill()
        }
        wait(for: [received], timeout: timeout)
    }

    func testHttpProxyRequiresCredentialsWhenConfigured() throws {
        let echoPort = try startEchoServer()
        let client = makeClient(proxyPort: startProxyServer(credentials: testCredentials))
        let challenged = expectation(description: "credenciales solicitadas")

        client.sendAndReadUntilClose(connectRequest(port: echoPort)) { response in
            XCTAssertTrue(String(decoding: response, as: UTF8.self).hasPrefix("HTTP/1.1 407"))
            challenged.fulfill()
        }
        wait(for: [challenged], timeout: timeout)
    }

    func testHttpProxyAcceptsValidBasicCredentials() throws {
        let echoPort = try startEchoServer()
        let client = makeClient(proxyPort: startProxyServer(credentials: testCredentials))
        let token = Data("\(testCredentials.username):\(testCredentials.password)".utf8).base64EncodedString()
        let established = HttpProxyResponse.connectionEstablished()
        let accepted = expectation(description: "túnel autorizado")

        client.send(connectRequest(port: echoPort, extraHeaders: ["Proxy-Authorization: Basic \(token)"]), expecting: established.count) { response in
            XCTAssertEqual(response, established)
            accepted.fulfill()
        }
        wait(for: [accepted], timeout: timeout)
    }

    func testReportsBadGatewayWhenDestinationRefuses() {
        let client = makeClient(proxyPort: startProxyServer())
        let refused = expectation(description: "502 informado")

        client.sendAndReadUntilClose(connectRequest(port: 1)) { response in
            XCTAssertTrue(String(decoding: response, as: UTF8.self).hasPrefix("HTTP/1.1 502"))
            refused.fulfill()
        }
        wait(for: [refused], timeout: timeout)
    }

    // MARK: - Estadísticas

    func testPublishesTrafficStatistics() throws {
        let echoPort = try startEchoServer()
        let proxyPort = startProxyServer()
        let client = makeClient(proxyPort: proxyPort)
        let payload = Array("estadisticas".utf8)
        let published = expectation(description: "estadísticas con tráfico")
        published.assertForOverFulfill = false

        server?.setStatisticsHandler { statistics in
            if statistics.bytesDownloaded >= UInt64(payload.count), statistics.acceptedConnections == 1 {
                published.fulfill()
            }
        }
        client.send(Socks5TestClient.greetingNoAuth, expecting: Socks5TestClient.methodSelectionLength) { _ in
            client.send(Socks5TestClient.loopbackRequest(command: 0x01, port: echoPort), expecting: Socks5TestClient.replyLength) { _ in
                client.send(payload, expecting: payload.count) { _ in }
            }
        }
        wait(for: [published], timeout: timeout)
    }

    // MARK: - Ayudantes

    private func startEchoServer() throws -> UInt16 {
        let echo = try EchoServer()
        echoServer = echo
        let ready = expectation(description: "eco listo")
        var port: UInt16 = 0
        echo.start(queue: queue) { readyPort in
            port = readyPort
            ready.fulfill()
        }
        wait(for: [ready], timeout: timeout)
        return port
    }

    private let testCredentials = ProxyCredentials(username: "usuario", password: "clave-de-prueba")

    private func startProxyServer(credentials: ProxyCredentials? = nil) -> UInt16 {
        var configuration = ProxyServerConfiguration.default
        configuration.port = UInt16.random(in: 20_000...45_000)
        configuration.credentials = credentials

        let directConnector = NetworkOutboundConnector(makeParameters: { NWParameters.tcp })
        let server = ProxyServer(
            configuration: configuration,
            transport: NetworkListenerTransport.loopback(),
            connector: directConnector
        )
        self.server = server

        let running = expectation(description: "proxy activo")
        running.assertForOverFulfill = false
        server.setStateHandler { state in
            if case .running = state {
                running.fulfill()
            }
        }
        server.start()
        wait(for: [running], timeout: timeout)
        return configuration.port
    }

    private func connectRequest(port: UInt16, extraHeaders: [String] = []) -> [UInt8] {
        let lines = ["CONNECT 127.0.0.1:\(port) HTTP/1.1", "Host: 127.0.0.1:\(port)"] + extraHeaders
        return Array((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
    }

    private func makeClient(proxyPort: UInt16) -> Socks5TestClient {
        let client = Socks5TestClient(proxyPort: proxyPort, queue: queue)
        self.client = client
        return client
    }
}
