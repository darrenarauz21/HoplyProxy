import ProxyCore
import XCTest
@testable import ProxyConfig

final class ProxyServerConfigurationFactoryTests: XCTestCase {
    func testMapsUsbSettingsWithoutAuthentication() throws {
        let configuration = try ProxyServerConfigurationFactory.make(from: .default, password: "ignorada-123456")

        XCTAssertEqual(configuration.listenScope, .loopback)
        XCTAssertNil(configuration.credentials)
        XCTAssertEqual(configuration.allowedClients, [])
        XCTAssertEqual(configuration.port, 1080)
        XCTAssertTrue(configuration.isValid)
    }

    func testMapsWiFiSettingsWithAuthentication() throws {
        var settings = ProxySettings.default
        settings.transport = .wifi
        settings.allowedClients = ["192.168.1.0/24"]
        settings.authenticationEnabled = true
        settings.username = "tp-abc123"

        let configuration = try ProxyServerConfigurationFactory.make(from: settings, password: "ClaveSegura2026")

        XCTAssertEqual(configuration.listenScope, .wifi)
        XCTAssertEqual(configuration.credentials, ProxyCredentials(username: "tp-abc123", password: "ClaveSegura2026"))
        XCTAssertEqual(configuration.allowedClients.map(\.description), ["192.168.1.0/24"])
        XCTAssertTrue(configuration.isValid)
    }

    func testThrowsValidationIssues() {
        var settings = ProxySettings.default
        settings.transport = .wifi

        XCTAssertThrowsError(try ProxyServerConfigurationFactory.make(from: settings, password: nil)) { error in
            XCTAssertEqual(error as? ProxySettingsValidationError, ProxySettingsValidationError(issues: [.allowedClientsRequired]))
        }
    }
}
