import ProxyConfig
import SwiftUI

struct SetupSummaryStep: View {
    let details: ClientConnectionDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("setup.summary.header")
                .font(Theme.title(.title))
                .foregroundStyle(Theme.text)

            Card {
                HStack(spacing: 12) {
                    IconBadge(systemName: details.transport.systemImage)
                    Text(details.transport.titleKey)
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                }
                Divider()
                CopyField(titleKey: "home.connection.proxy", value: details.proxyAddress)
                if let username = details.username {
                    Divider()
                    CopyField(titleKey: "settings.auth.username", value: username)
                }
            }

            Text("setup.summary.footer")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 4)
        }
    }
}
