import XCTest
@testable import Socks5

final class Socks5GreetingTests: XCTestCase {
    func testParsesCompleteGreeting() throws {
        let result = try Socks5Greeting.parse([0x05, 0x02, 0x00, 0x02])

        XCTAssertEqual(result, .complete(Socks5Greeting(methods: [0x00, 0x02]), consumed: 4))
    }

    func testReportsNeedMoreDataForPartialGreeting() throws {
        XCTAssertEqual(try Socks5Greeting.parse([]), .needMoreData)
        XCTAssertEqual(try Socks5Greeting.parse([0x05]), .needMoreData)
        XCTAssertEqual(try Socks5Greeting.parse([0x05, 0x02, 0x00]), .needMoreData)
    }

    func testConsumesOnlyGreetingBytes() throws {
        let result = try Socks5Greeting.parse([0x05, 0x01, 0x00, 0x05, 0x01])

        XCTAssertEqual(result, .complete(Socks5Greeting(methods: [0x00]), consumed: 3))
    }

    func testRejectsUnsupportedVersion() {
        XCTAssertThrowsError(try Socks5Greeting.parse([0x04, 0x01, 0x00])) { error in
            XCTAssertEqual(error as? Socks5ProtocolError, .unsupportedVersion(0x04))
        }
    }

    func testRejectsGreetingWithoutMethods() {
        XCTAssertThrowsError(try Socks5Greeting.parse([0x05, 0x00])) { error in
            XCTAssertEqual(error as? Socks5ProtocolError, .noAuthenticationMethods)
        }
    }

    func testSelectsFirstSupportedMethodInServerOrder() {
        let greeting = Socks5Greeting(methods: [0x02, 0x00])

        XCTAssertEqual(greeting.selectMethod(preferredOrder: [.noAuthentication]), .noAuthentication)
        XCTAssertEqual(
            greeting.selectMethod(preferredOrder: [.usernamePassword, .noAuthentication]),
            .usernamePassword
        )
    }

    func testReturnsNoAcceptableMethodWhenThereIsNoMatch() {
        let greeting = Socks5Greeting(methods: [0x01, 0xFF])

        XCTAssertEqual(greeting.selectMethod(preferredOrder: [.noAuthentication]), .noAcceptableMethods)
        XCTAssertEqual(greeting.selectMethod(preferredOrder: [.noAcceptableMethods]), .noAcceptableMethods)
    }
}
