import XCTest
@testable import ProxyConfig

final class PersistenceAndCredentialTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ProxyConfigTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testStoreReturnsDefaultsWhenEmpty() {
        let store = UserDefaultsProxySettingsStore(defaults: defaults)

        XCTAssertEqual(store.loadSettings(), .default)
        XCTAssertFalse(store.hasCompletedSetup)
    }

    func testStoreRoundTrip() throws {
        let store = UserDefaultsProxySettingsStore(defaults: defaults)
        var settings = ProxySettings.default
        settings.transport = .wifi
        settings.allowedClients = ["192.168.1.0/24"]

        try store.saveSettings(settings)
        store.hasCompletedSetup = true

        let reloaded = UserDefaultsProxySettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.loadSettings(), settings)
        XCTAssertTrue(reloaded.hasCompletedSetup)
    }

    func testDecodingFillsMissingFieldsWithDefaults() throws {
        let json = Data(#"{"transport":"wifi","port":2080}"#.utf8)

        let settings = try JSONDecoder().decode(ProxySettings.self, from: json)

        XCTAssertEqual(settings.transport, .wifi)
        XCTAssertEqual(settings.port, 2080)
        XCTAssertEqual(settings.maximumConnections, ProxySettings.default.maximumConnections)
    }

    func testGeneratedCredentialsPassValidation() {
        for _ in 0..<50 {
            XCTAssertTrue(ProxySettingsValidator.isValidUsername(CredentialGenerator.makeUsername()))
            XCTAssertTrue(ProxySettingsValidator.isValidPassword(CredentialGenerator.makePassword()))
        }
        XCTAssertNotEqual(CredentialGenerator.makePassword(), CredentialGenerator.makePassword())
    }
}
