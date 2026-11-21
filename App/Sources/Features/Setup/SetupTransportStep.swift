import ProxyConfig
import ProxyCore
import SwiftUI

struct SetupTransportStep: View {
    @Binding var selection: TransportMode
    let wifiNetwork: LocalWiFiNetwork?
    let issues: [ProxySettingsIssue]
    let didFailToPersist: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("setup.transport.header")
                .font(Theme.title(.title))
                .foregroundStyle(Theme.text)

            VStack(spacing: 12) {
                ForEach(TransportMode.allCases, id: \.self) { mode in
                    TransportOptionCard(mode: mode, isSelected: mode == selection) {
                        selection = mode
                    }
                }
            }

            if selection == .wifi {
                if let wifiNetwork {
                    Label {
                        Text("setup.wifi.network \(wifiNetwork.subnet.description)")
                    } icon: {
                        Image(systemName: "wifi")
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                } else {
                    NoticeLabel(textKey: "setup.wifi.notConnected", systemImage: "wifi.slash")
                }
            }

            if !issues.isEmpty || didFailToPersist {
                ValidationMessagesView(issues: issues, showsPersistenceError: didFailToPersist)
            }
        }
    }
}

private struct TransportOptionCard: View {
    let mode: TransportMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                IconBadge(systemName: mode.systemImage, tint: isSelected ? Theme.accent : Theme.secondaryText, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.titleKey)
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Text(mode.descriptionKey)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.border)
                    .accessibilityHidden(true)
            }
            .padding(Theme.spacing)
            .background(
                isSelected ? Theme.accent.opacity(0.08) : Theme.raised,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Theme.border, lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
