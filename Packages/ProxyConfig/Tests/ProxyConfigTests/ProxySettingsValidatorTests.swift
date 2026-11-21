import XCTest
@testable import ProxyConfig

final class ProxySettingsValidatorTests: XCTestCase {
    func testDefaultSettingsAreValid() {
        XCTAssertEqual(ProxySettingsValidator.validate(.default, password: nil), [])
    }

    func testReportsOutOfRangeValues() {
        var settings = ProxySettings.default
        settings.port = 80
        settings.maximumConnections = 0
        settings.idleTimeoutSeconds = 1

        let issues = ProxySettingsValidator.validate(settings, password: nil)

        XCTAssertEqual(issues, [.portOutOfRange, .maximumConnectionsOutOfRange, .idleTimeoutOutOfRange])
    }

    func testAuthenticationRequiresValidCredentials() {
        var settings = ProxySettings.default
        settings.authenticationEnabled = true
        settings.username = "a b"

        XCTAssertEqual(
            ProxySettingsValidator.validate(settings, password: "corta"),
            [.usernameInvalid, .passwordInvalid]
        )

        settings.username = "tp-usuario"
        XCTAssertEqual(ProxySettingsValidator.validate(settings, password: "ClaveSegura2026"), [])
        XCTAssertEqual(ProxySettingsValidator.validate(settings, password: nil), [.passwordInvalid])
        XCTAssertEqual(ProxySettingsValidator.validate(settings, password: "con espacio 123"), [.passwordInvalid])
    }

    func testWiFiRequiresAllowList() {
        var settings = ProxySettings.default
        settings.transport = .wifi

        XCTAssertEqual(ProxySettingsValidator.validate(settings, password: nil), [.allowedClientsRequired])

        settings.allowedClients = ["192.168.1.0/24", "10.0.0.7"]
        XCTAssertEqual(ProxySettingsValidator.validate(settings, password: nil), [])
    }

    func testRejectsInvalidAndBroadAllowListEntries() {
        var settings = ProxySettings.default
        settings.transport = .wifi
        settings.allowedClients = ["192.168.1.300", "0.0.0.0/0"]

        XCTAssertEqual(
            ProxySettingsValidator.validate(settings, password: nil),
            [.allowedClientInvalid("192.168.1.300"), .allowedClientTooBroad("0.0.0.0/0")]
        )
    }

    func testRejectsTooManyAllowListEntries() {
        var settings = ProxySettings.default
        settings.transport = .wifi
        settings.allowedClients = (1...17).map { "192.168.1.\($0)" }

        XCTAssertEqual(ProxySettingsValidator.validate(settings, password: nil), [.tooManyAllowedClients])
    }

    func testAllowListIsIgnoredOverUsb() {
        var settings = ProxySettings.default
        settings.allowedClients = ["no es una ip"]

        XCTAssertEqual(ProxySettingsValidator.validate(settings, password: nil), [])
    }
}
