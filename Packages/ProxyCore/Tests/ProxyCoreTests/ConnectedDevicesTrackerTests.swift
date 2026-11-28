import Network
import XCTest
@testable import ProxyCore

final class ConnectedDevicesTrackerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 0)

    func testManyConnectionsFromTheSameLaptopCountAsOneDevice() {
        var tracker = ConnectedDevicesTracker()

        for second in 0..<100 {
            let date = start + TimeInterval(second)
            tracker.connectionOpened(by: "127.0.0.1", at: date)
            tracker.connectionClosed(by: "127.0.0.1", at: date)
        }

        XCTAssertEqual(tracker.count(at: start + 100), 1)
    }

    func testCountsEachAddressOnce() {
        var tracker = ConnectedDevicesTracker()

        tracker.connectionOpened(by: "192.168.1.20", at: start)
        tracker.connectionOpened(by: "192.168.1.20", at: start)
        tracker.connectionOpened(by: "192.168.1.21", at: start)

        XCTAssertEqual(tracker.count(at: start), 2)
    }

    func testForgetsDevicesAfterTheIdleWindow() {
        var tracker = ConnectedDevicesTracker()
        tracker.connectionOpened(by: "127.0.0.1", at: start)
        tracker.connectionClosed(by: "127.0.0.1", at: start)

        XCTAssertEqual(tracker.count(at: start + ConnectedDevicesTracker.idleWindow - 1), 1)
        XCTAssertEqual(tracker.count(at: start + ConnectedDevicesTracker.idleWindow), 0)
    }

    func testKeepsDevicesWithOpenConnectionsBeyondTheIdleWindow() {
        var tracker = ConnectedDevicesTracker()
        tracker.connectionOpened(by: "127.0.0.1", at: start)

        XCTAssertEqual(tracker.count(at: start + ConnectedDevicesTracker.idleWindow * 10), 1)
    }

    func testResetForgetsEveryDevice() {
        var tracker = ConnectedDevicesTracker()
        tracker.connectionOpened(by: "127.0.0.1", at: start)

        tracker.reset()

        XCTAssertEqual(tracker.count(at: start), 0)
    }

    func testIdentifiesTheDeviceWithoutTheSourcePort() {
        let first = NWEndpoint.hostPort(host: "192.168.1.20", port: 50_000)
        let second = NWEndpoint.hostPort(host: "192.168.1.20", port: 50_001)

        XCTAssertEqual(ConnectedDevicesTracker.device(of: first), "192.168.1.20")
        XCTAssertEqual(ConnectedDevicesTracker.device(of: first), ConnectedDevicesTracker.device(of: second))
    }
}
