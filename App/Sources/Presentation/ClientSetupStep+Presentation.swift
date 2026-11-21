import ProxyConfig
import SwiftUI

extension ClientSetupStep {
    var instructionKey: LocalizedStringKey {
        switch self {
        case .connectCable:
            return "guide.connectCable"
        case .installAppleDevices:
            return "guide.installAppleDevices"
        case .installUsbmuxd:
            return "guide.installUsbmuxd"
        case .installGoIos:
            return "guide.installGoIos"
        case .runForward:
            return "guide.runForward"
        case .joinSameWiFi:
            return "guide.joinSameWiFi"
        case .configureSystemPac(let platform, _):
            switch platform {
            case .windows:
                return "guide.pac.windows"
            case .macOS:
                return "guide.pac.macOS"
            case .linux:
                return "guide.pac.linux"
            }
        case .configureFirefox:
            return "guide.firefox"
        case .enterCredentials(let username):
            return "guide.enterCredentials \(username)"
        case .verify:
            return "guide.verify"
        case .systemWideTunnel:
            return "guide.systemWideTunnel"
        }
    }

    /// Valor que el usuario copia a la laptop, si el paso tiene uno.
    var copyValue: String? {
        switch self {
        case .installUsbmuxd(let command),
             .installGoIos(let command),
             .runForward(let command),
             .verify(let command):
            return command
        case .configureSystemPac(_, let url):
            return url
        case .configureFirefox(let proxyAddress):
            return proxyAddress
        case .connectCable, .installAppleDevices, .joinSameWiFi, .enterCredentials, .systemWideTunnel:
            return nil
        }
    }
}
