import Network
import Socks5
import XCTest
@testable import ProxyCore

final class OutboundConnectionErrorTests: XCTestCase {
    func testMapsNetworkErrors() {
        XCTAssertEqual(OutboundConnectionError(.posix(.ECONNREFUSED)), .connectionRefused)
        XCTAssertEqual(OutboundConnectionError(.posix(.ENETUNREACH)), .networkUnreachable)
        XCTAssertEqual(OutboundConnectionError(.posix(.EHOSTUNREACH)), .hostUnreachable)
        XCTAssertEqual(OutboundConnectionError(.posix(.ETIMEDOUT)), .timedOut)
        XCTAssertEqual(OutboundConnectionError(.posix(.EPERM)), .failed)
    }

    func testMapsErrorsToReplyCodes() {
        XCTAssertEqual(OutboundConnectionError.connectionRefused.replyCode, .connectionRefused)
        XCTAssertEqual(OutboundConnectionError.networkUnreachable.replyCode, .networkUnreachable)
        XCTAssertEqual(OutboundConnectionError.timedOut.replyCode, .hostUnreachable)
        XCTAssertEqual(OutboundConnectionError.invalidDestination.replyCode, .generalFailure)
    }
}
