import ProxyConfig
import SwiftUI

extension TransportMode {
    var titleKey: LocalizedStringKey {
        switch self {
        case .usb:
            return "transport.usb"
        case .wifi:
            return "transport.wifi"
        }
    }

    var descriptionKey: LocalizedStringKey {
        switch self {
        case .usb:
            return "transport.usb.description"
        case .wifi:
            return "transport.wifi.description"
        }
    }

    var systemImage: String {
        switch self {
        case .usb:
            return "cable.connector"
        case .wifi:
            return "wifi"
        }
    }
}
