import XCTest
@testable import Socks5

final class Socks5UserPassRequestTests: XCTestCase {
    func testParsesCredentials() throws {
        let bytes: [UInt8] = [0x01, 0x03] + Array("ana".utf8) + [0x04] + Array("clav".utf8)

        let result = try Socks5UserPassRequest.parse(bytes)

        let expected = Socks5UserPassRequest(username: Array("ana".utf8), password: Array("clav".utf8))
        XCTAssertEqual(result, .complete(expected, consumed: bytes.count))
    }

    func testReportsNeedMoreDataAtEveryStage() throws {
        let complete: [UInt8] = [0x01, 0x02] + Array("ab".utf8) + [0x02] + Array("cd".utf8)

        for length in 0..<complete.count {
            XCTAssertEqual(
                try Socks5UserPassRequest.parse(Array(complete.prefix(length))),
                .needMoreData,
                "Longitud \(length)"
            )
        }
    }

    func testRejectsUnsupportedVersion() {
        XCTAssertThrowsError(try Socks5UserPassRequest.parse([0x05, 0x01])) { error in
            XCTAssertEqual(error as? Socks5ProtocolError, .unsupportedAuthenticationVersion(0x05))
        }
    }

    func testRejectsEmptyUsernameOrPassword() {
        XCTAssertThrowsError(try Socks5UserPassRequest.parse([0x01, 0x00])) { error in
            XCTAssertEqual(error as? Socks5ProtocolError, .invalidCredentialsFormat)
        }
        XCTAssertThrowsError(try Socks5UserPassRequest.parse([0x01, 0x01, 0x61, 0x00])) { error in
            XCTAssertEqual(error as? Socks5ProtocolError, .invalidCredentialsFormat)
        }
    }

    func testEncodesAuthenticationStatus() {
        XCTAssertEqual(Socks5ResponseEncoder.authenticationStatus(succeeded: true), [0x01, 0x00])
        XCTAssertEqual(Socks5ResponseEncoder.authenticationStatus(succeeded: false), [0x01, 0x01])
    }
}
