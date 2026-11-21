import Network
import XCTest
@testable import ProxyCore

final class ProxyActivityRecorderTests: XCTestCase {
    private let laptop = NWEndpoint.hostPort(host: "192.168.1.20", port: 50_000)

    func testAccumulatesTrafficAndConnections() {
        let recorder = ProxyActivityRecorder()

        recorder.recordAcceptedConnection()
        recorder.recordTransfer(100, direction: .upstream)
        recorder.recordTransfer(250, direction: .downstream)
        recorder.recordOutboundFailure(.timedOut)
        recorder.recordRejectedConnection(from: laptop, reason: .notAllowed)

        XCTAssertEqual(recorder.statistics, ProxyTrafficStatistics(
            bytesUploaded: 100,
            bytesDownloaded: 250,
            acceptedConnections: 1,
            rejectedConnections: 1,
            failedConnections: 1
        ))
    }

    func testGroupsRepeatedEventsWithinThrottleInterval() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let recorder = ProxyActivityRecorder(now: { currentDate })
        var events: [ProxyEvent] = []
        recorder.eventHandler = { events.append($0) }

        recorder.recordOutboundFailure(.networkUnreachable)
        recorder.recordOutboundFailure(.networkUnreachable)
        recorder.recordOutboundFailure(.connectionRefused)
        currentDate += ProxyActivityRecorder.eventThrottleInterval
        recorder.recordOutboundFailure(.networkUnreachable)

        XCTAssertEqual(events.map(\.kind), [
            .destinationUnreachable(.networkUnreachable),
            .destinationUnreachable(.connectionRefused),
            .destinationUnreachable(.networkUnreachable),
        ])
    }

    func testRejectionEventIncludesClientAddress() {
        let recorder = ProxyActivityRecorder()
        var events: [ProxyEvent] = []
        recorder.eventHandler = { events.append($0) }

        recorder.recordRejectedConnection(from: laptop, reason: .notAllowed)

        XCTAssertEqual(events.first?.kind, .clientRejected(address: "192.168.1.20", reason: .notAllowed))
    }
}
