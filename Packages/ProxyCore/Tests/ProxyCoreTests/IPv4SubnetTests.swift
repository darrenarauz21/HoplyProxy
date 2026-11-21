import XCTest
@testable import ProxyCore

final class IPv4SubnetTests: XCTestCase {
    func testParsesSubnetAndMasksNetworkAddress() throws {
        let subnet = try XCTUnwrap(IPv4Subnet("192.168.1.77/24"))

        XCTAssertEqual(subnet.description, "192.168.1.0/24")
        XCTAssertEqual(subnet.prefixLength, 24)
    }

    func testSingleAddressIsSlash32() throws {
        let subnet = try XCTUnwrap(IPv4Subnet(" 10.0.0.5 "))

        XCTAssertEqual(subnet.description, "10.0.0.5/32")
    }

    func testContainsAddressesInRange() throws {
        let subnet = try XCTUnwrap(IPv4Subnet("172.20.10.0/28"))

        XCTAssertTrue(subnet.contains(try XCTUnwrap(IPv4Subnet.parseAddress("172.20.10.1"))))
        XCTAssertTrue(subnet.contains(try XCTUnwrap(IPv4Subnet.parseAddress("172.20.10.15"))))
        XCTAssertFalse(subnet.contains(try XCTUnwrap(IPv4Subnet.parseAddress("172.20.10.16"))))
    }

    func testPrefixZeroContainsEverything() throws {
        let subnet = try XCTUnwrap(IPv4Subnet("0.0.0.0/0"))

        XCTAssertTrue(subnet.contains(try XCTUnwrap(IPv4Subnet.parseAddress("8.8.8.8"))))
    }

    func testRejectsInvalidText() {
        let invalid = ["", "192.168.1", "192.168.1.256", "192.168.1.1/33", "192.168.1.1/", "+1.2.3.4", "a.b.c.d", "1.2.3.4/24/1", "1..2.3"]
        for text in invalid {
            XCTAssertNil(IPv4Subnet(text), text)
        }
    }

    func testFormatsAddress() {
        XCTAssertEqual(IPv4Subnet.formatAddress(0xC0A8_0105), "192.168.1.5")
    }
}
