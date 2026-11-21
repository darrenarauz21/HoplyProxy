import XCTest
@testable import ProxyConfig

final class SignatureExpiryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testExtractsExpirationDateFromSignedProfile() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>Name</key><string>Perfil</string>
        <key>ExpirationDate</key><date>2027-01-08T15:30:00Z</date>
        </dict></plist>
        """
        let signedProfile = Data([0x30, 0x82, 0x0F, 0x00]) + Data(plist.utf8) + Data([0xA0, 0x82, 0x01])

        let date = ProvisioningProfileParser.expirationDate(from: signedProfile)

        XCTAssertEqual(date, ISO8601DateFormatter().date(from: "2027-01-08T15:30:00Z"))
    }

    func testReturnsNilWithoutPlist() {
        XCTAssertNil(ProvisioningProfileParser.expirationDate(from: Data("sin perfil".utf8)))
    }

    func testEvaluatesStatusAroundWarningInterval() {
        let warning = SignatureExpiryStatus.warningInterval
        let later = now.addingTimeInterval(warning + 60)
        let soon = now.addingTimeInterval(warning - 60)
        let past = now.addingTimeInterval(-1)

        XCTAssertEqual(SignatureExpiryStatus.evaluate(expirationDate: nil, now: now), .unknown)
        XCTAssertEqual(SignatureExpiryStatus.evaluate(expirationDate: later, now: now), .valid(expiresAt: later))
        XCTAssertEqual(SignatureExpiryStatus.evaluate(expirationDate: soon, now: now), .expiringSoon(expiresAt: soon))
        XCTAssertEqual(SignatureExpiryStatus.evaluate(expirationDate: past, now: now), .expired(expiresAt: past))
    }

    func testReminderIsOneDayBeforeExpiration() {
        let expiration = now.addingTimeInterval(3 * SignatureExpiryStatus.warningInterval)

        XCTAssertEqual(
            SignatureExpiryStatus.reminderDate(forExpiration: expiration, now: now),
            expiration.addingTimeInterval(-SignatureExpiryStatus.warningInterval)
        )
        XCTAssertNil(SignatureExpiryStatus.reminderDate(forExpiration: now.addingTimeInterval(60), now: now))
    }
}
