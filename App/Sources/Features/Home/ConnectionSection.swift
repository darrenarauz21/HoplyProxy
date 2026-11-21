import ProxyConfig
import SwiftUI

/// Datos que la laptop necesita, listos para copiar.
struct ConnectionSection: View {
    let details: ClientConnectionDetails
    let isWiFiUnavailable: Bool

    var body: some View {
        Card {
            HStack(spacing: 12) {
                IconBadge(systemName: details.transport.systemImage)
                Text("home.connection.section")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(details.transport.titleKey)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.15), in: Capsule())
            }

            if details.transport == .wifi {
                CopyField(titleKey: "home.connection.iphoneIP", value: details.proxyHost)
                Divider()
            }
            CopyField(titleKey: "home.connection.proxy", value: details.proxyAddress)
            Divider()
            CopyField(titleKey: "home.connection.pac", value: details.pacURL)

            if isWiFiUnavailable {
                NoticeLabel(textKey: "home.connection.wifiUnavailable", systemImage: "wifi.slash")
            }
        }
    }
}
