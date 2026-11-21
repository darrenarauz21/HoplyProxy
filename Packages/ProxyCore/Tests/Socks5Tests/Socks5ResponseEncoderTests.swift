import XCTest
@testable import Socks5

final class Socks5ResponseEncoderTests: XCTestCase {
    func testEncodesMethodSelection() {
        XCTAssertEqual(Socks5ResponseEncoder.methodSelection(.noAuthentication), [0x05, 0x00])
        XCTAssertEqual(Socks5ResponseEncoder.methodSelection(.noAcceptableMethods), [0x05, 0xFF])
    }

    func testEncodesReplyWithUnspecifiedBoundAddress() {
        XCTAssertEqual(
            Socks5ResponseEncoder.reply(.succeeded),
            [0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]
        )
        XCTAssertEqual(Socks5ResponseEncoder.reply(.connectionRefused)[1], 0x05)
    }
}
