import XCTest
@testable import ProxyCore

final class ProxyServerConfigurationTests: XCTestCase {
    func testDefaultConfigurationIsValid() {
        XCTAssertTrue(ProxyServerConfiguration.default.isValid)
    }

    func testRejectsPrivilegedPort() {
        var configuration = ProxyServerConfiguration.default
        configuration.port = 80

        XCTAssertFalse(configuration.isValid)
    }

    func testRejectsValuesOutOfRange() {
        var configuration = ProxyServerConfiguration.default
        configuration.maximumConnections = 0
        XCTAssertFalse(configuration.isValid)

        configuration = .default
        configuration.idleTimeout = 1
        XCTAssertFalse(configuration.isValid)

        configuration = .default
        configuration.connectTimeout = 0
        XCTAssertFalse(configuration.isValid)
    }
}
