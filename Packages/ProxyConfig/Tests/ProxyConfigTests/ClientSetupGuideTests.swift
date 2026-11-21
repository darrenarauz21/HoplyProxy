import XCTest
@testable import ProxyConfig

final class ClientSetupGuideTests: XCTestCase {
    func testUsbOnWindowsWithoutAuthentication() {
        let details = ClientConnectionDetails(transport: .usb, proxyHost: "127.0.0.1", port: 1080, username: nil)

        let steps = ClientSetupGuide.steps(for: .windows, details: details)

        XCTAssertEqual(steps, [
            .connectCable,
            .installAppleDevices,
            .installGoIos(command: "npm install -g go-ios"),
            .runForward(command: "ios forward 1080 1080"),
            .configureSystemPac(platform: .windows, url: "http://127.0.0.1:1080/proxy.pac"),
            .configureFirefox(proxyAddress: "127.0.0.1:1080"),
            .verify(command: "curl --proxy http://127.0.0.1:1080 https://ifconfig.me"),
            .systemWideTunnel,
        ])
    }

    func testWiFiOnLinuxWithAuthentication() {
        let details = ClientConnectionDetails(transport: .wifi, proxyHost: "192.168.1.5", port: 1080, username: "tp-abc123")

        let steps = ClientSetupGuide.steps(for: .linux, details: details)

        XCTAssertEqual(steps, [
            .joinSameWiFi,
            .configureSystemPac(platform: .linux, url: "http://192.168.1.5:1080/proxy.pac"),
            .configureFirefox(proxyAddress: "192.168.1.5:1080"),
            .enterCredentials(username: "tp-abc123"),
            .verify(command: "curl --proxy http://192.168.1.5:1080 --proxy-user tp-abc123 https://ifconfig.me"),
            .systemWideTunnel,
        ])
    }

    func testUsbOnLinuxInstallsUsbmuxd() {
        let details = ClientConnectionDetails(transport: .usb, proxyHost: "127.0.0.1", port: 1080, username: nil)

        let steps = ClientSetupGuide.steps(for: .linux, details: details)

        XCTAssertEqual(steps[1], .installUsbmuxd(command: "sudo apt install usbmuxd"))
    }
}
