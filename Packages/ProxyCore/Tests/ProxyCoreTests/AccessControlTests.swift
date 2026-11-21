import Network
import XCTest
@testable import ProxyCore

final class AccessControlTests: XCTestCase {
    func testCredentialComparison() {
        XCTAssertTrue(CredentialVerifier.constantTimeEquals(Array("abc".utf8), Array("abc".utf8)))
        XCTAssertFalse(CredentialVerifier.constantTimeEquals(Array("abc".utf8), Array("abd".utf8)))
        XCTAssertFalse(CredentialVerifier.constantTimeEquals(Array("abc".utf8), Array("abcd".utf8)))
        XCTAssertFalse(CredentialVerifier.constantTimeEquals([], Array("a".utf8)))
    }

    func testVerifierRequiresBothValues() {
        let verifier = CredentialVerifier(credentials: ProxyCredentials(username: "ana", password: "secreto"))

        XCTAssertTrue(verifier.verify(username: Array("ana".utf8), password: Array("secreto".utf8)))
        XCTAssertFalse(verifier.verify(username: Array("ana".utf8), password: Array("otro".utf8)))
        XCTAssertFalse(verifier.verify(username: Array("eva".utf8), password: Array("secreto".utf8)))
    }

    func testWiFiPolicyUsesAllowList() throws {
        let policy = ClientAccessPolicy(scope: .wifi, allowedClients: [try XCTUnwrap(IPv4Subnet("192.168.1.0/24"))])

        XCTAssertTrue(policy.allows(.hostPort(host: "192.168.1.20", port: 50_000)))
        XCTAssertFalse(policy.allows(.hostPort(host: "192.168.2.20", port: 50_000)))
        XCTAssertTrue(policy.allows(.hostPort(host: "::ffff:192.168.1.20", port: 50_000)))
        XCTAssertFalse(policy.allows(.hostPort(host: "fe80::1", port: 50_000)))
    }

    func testLoopbackPolicyAllowsLocalConnections() {
        let policy = ClientAccessPolicy(scope: .loopback, allowedClients: [])

        XCTAssertTrue(policy.allows(.hostPort(host: "127.0.0.1", port: 50_000)))
    }

    func testWiFiConfigurationRequiresAllowList() throws {
        var configuration = ProxyServerConfiguration.default
        configuration.listenScope = .wifi
        XCTAssertFalse(configuration.isValid)

        configuration.allowedClients = [try XCTUnwrap(IPv4Subnet("192.168.1.0/24"))]
        XCTAssertTrue(configuration.isValid)
    }
}
