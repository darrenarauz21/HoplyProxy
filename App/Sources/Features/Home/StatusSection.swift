import ProxyConfig
import ProxyCore
import SwiftUI

/// Estado del proxy y el botón para iniciarlo o detenerlo.
struct StatusSection: View {
    let state: ProxyServerState
    let startIssues: [ProxySettingsIssue]
    let isCellularUnavailable: Bool
    let keepsRunningInBackground: Bool
    let onToggle: () -> Void

    var body: some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: state.statusSymbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(state.statusColor)
                    .frame(width: 56, height: 56)
                    .background(state.statusColor.opacity(0.15), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.statusTitleKey)
                        .font(Theme.title(.title2))
                        .foregroundStyle(Theme.text)
                    subtitle
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 0)
            }

            messages

            Button(action: onToggle) {
                Text(state.toggleActionKey)
            }
            .buttonStyle(PrimaryButtonStyle(isDestructive: state.isActive))
        }
    }

    /// Los equipos conectados se ven en el indicador de tráfico; aquí, si el proxy sigue con la pantalla bloqueada.
    private var subtitle: some View {
        Text(keepsRunningInBackground ? "home.backgroundEnabled" : "home.keepOpen")
    }

    @ViewBuilder
    private var messages: some View {
        if let failureMessageKey = state.failureMessageKey {
            NoticeLabel(textKey: failureMessageKey, systemImage: "xmark.octagon.fill", tint: Theme.danger)
        }
        if isCellularUnavailable {
            NoticeLabel(textKey: "home.cellularUnavailable", systemImage: "antenna.radiowaves.left.and.right.slash")
        }
        if !startIssues.isEmpty {
            ValidationMessagesView(issues: startIssues)
        }
    }
}
