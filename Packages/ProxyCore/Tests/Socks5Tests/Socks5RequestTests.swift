import XCTest
@testable import Socks5

final class Socks5RequestTests: XCTestCase {
    func testParsesIPv4ConnectRequest() throws {
        let bytes: [UInt8] = [0x05, 0x01, 0x00, 0x01, 93, 184, 216, 34, 0x01, 0xBB]

        let result = try Socks5Request.parse(bytes)

        let expected = Socks5Request(
            command: .connect,
            destination: Socks5Destination(address: .ipv4([93, 184, 216, 34]), port: 443)
        )
        XCTAssertEqual(result, .complete(expected, consumed: 10))
    }

    func testParsesDomainConnectRequest() throws {
        let name = Array("example.com".utf8)
        let bytes: [UInt8] = [0x05, 0x01, 0x00, 0x03, UInt8(name.count)] + name + [0x00, 0x50]

        let result = try Socks5Request.parse(bytes)

        let expected = Socks5Request(
            command: .connect,
            destination: Socks5Destination(address: .domain("example.com"), port: 80)
        )
        XCTAssertEqual(result, .complete(expected, consumed: bytes.count))
    }

    func testParsesIPv6ConnectRequest() throws {
        let address: [UInt8] = [0x20, 0x01, 0x0D, 0xB8] + Array(repeating: 0, count: 11) + [0x01]
        let bytes: [UInt8] = [0x05, 0x01, 0x00, 0x04] + address + [0x1F, 0x90]

        let result = try Socks5Request.parse(bytes)

        let expected = Socks5Request(
            command: .connect,
            destination: Socks5Destination(address: .ipv6(address), port: 8080)
        )
        XCTAssertEqual(result, .complete(expected, consumed: 22))
    }

    func testReportsNeedMoreDataAtEveryStage() throws {
        let name = Array("host".utf8)
        let complete: [UInt8] = [0x05, 0x01, 0x00, 0x03, UInt8(name.count)] + name + [0x00, 0x50]

        for length in 0..<complete.count {
            XCTAssertEqual(
                try Socks5Request.parse(Array(complete.prefix(length))),
                .needMoreData,
                "Longitud \(length)"
            )
        }
    }

    func testKeepsTrailingBytesOutOfConsumedCount() throws {
        let bytes: [UInt8] = [0x05, 0x01, 0x00, 0x01, 127, 0, 0, 1, 0x00, 0x50, 0xAA, 0xBB]

        guard case let .complete(_, consumed) = try Socks5Request.parse(bytes) else {
            return XCTFail("Se esperaba una solicitud completa")
        }
        XCTAssertEqual(consumed, 10)
    }

    func testParsesBindSoTheServerCanRejectIt() throws {
        let bytes: [UInt8] = [0x05, 0x02, 0x00, 0x01, 127, 0, 0, 1, 0x00, 0x50]

        guard case let .complete(request, _) = try Socks5Request.parse(bytes) else {
            return XCTFail("Se esperaba una solicitud completa")
        }
        XCTAssertEqual(request.command, .bind)
    }

    func testRejectsUnknownCommand() {
        assertThrows([0x05, 0x09, 0x00, 0x01], .unsupportedCommand(0x09))
    }

    func testRejectsUnsupportedVersion() {
        assertThrows([0x04, 0x01, 0x00, 0x01], .unsupportedVersion(0x04))
    }

    func testRejectsNonZeroReservedByte() {
        assertThrows([0x05, 0x01, 0x01, 0x01], .invalidReservedByte(0x01))
    }

    func testRejectsUnknownAddressType() {
        assertThrows([0x05, 0x01, 0x00, 0x02], .unsupportedAddressType(0x02))
    }

    func testRejectsEmptyDomainName() {
        assertThrows([0x05, 0x01, 0x00, 0x03, 0x00, 0x00, 0x50], .invalidDomainName)
    }

    func testRejectsDomainNameWithInvalidCharacters() {
        let name = Array("bad host\r\n".utf8)
        let bytes: [UInt8] = [0x05, 0x01, 0x00, 0x03, UInt8(name.count)] + name + [0x00, 0x50]

        assertThrows(bytes, .invalidDomainName)
    }

    func testRejectsPortZero() {
        assertThrows([0x05, 0x01, 0x00, 0x01, 127, 0, 0, 1, 0x00, 0x00], .invalidPort)
    }

    func testMapsProtocolErrorsToReplyCodes() {
        XCTAssertEqual(Socks5ProtocolError.unsupportedCommand(0x09).replyCode, .commandNotSupported)
        XCTAssertEqual(Socks5ProtocolError.unsupportedAddressType(0x02).replyCode, .addressTypeNotSupported)
        XCTAssertEqual(Socks5ProtocolError.invalidDomainName.replyCode, .generalFailure)
    }

    private func assertThrows(
        _ bytes: [UInt8],
        _ expected: Socks5ProtocolError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try Socks5Request.parse(bytes), file: file, line: line) { error in
            XCTAssertEqual(error as? Socks5ProtocolError, expected, file: file, line: line)
        }
    }
}
