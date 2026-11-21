import ProxyConfig
import SwiftUI

/// Caducidad de la firma de 7 días. Se oculta si la app no tiene perfil de aprovisionamiento.
struct SignatureSection: View {
    @ObservedObject var signature: SignatureMonitor
    private static let refreshInterval: TimeInterval = 60

    var body: some View {
        if signature.expirationDate != nil {
            TimelineView(.periodic(from: .now, by: Self.refreshInterval)) { context in
                SignatureStatusCard(
                    status: signature.status(at: context.date),
                    isReminderAuthorized: signature.isReminderAuthorized
                )
            }
        }
    }
}

private struct SignatureStatusCard: View {
    let status: SignatureExpiryStatus
    let isReminderAuthorized: Bool

    var body: some View {
        Card {
            HStack(spacing: 12) {
                IconBadge(systemName: "calendar.badge.clock", tint: status.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("home.signature.expires")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                    if let expirationDate = status.expirationDate {
                        Text(expirationDate, format: .dateTime.weekday(.abbreviated).day().month().hour().minute())
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.text)
                    }
                }
            }
            if let messageKey = status.messageKey {
                NoticeLabel(textKey: messageKey, tint: status.tint)
            }
            if !isReminderAuthorized {
                Text("home.signature.notificationsDenied")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

private extension SignatureExpiryStatus {
    var messageKey: LocalizedStringKey? {
        switch self {
        case .unknown, .valid:
            return nil
        case .expiringSoon:
            return "home.signature.expiringSoon"
        case .expired:
            return "home.signature.expired"
        }
    }

    var tint: Color {
        switch self {
        case .unknown, .valid:
            return Theme.accent
        case .expiringSoon:
            return Theme.warning
        case .expired:
            return Theme.danger
        }
    }
}
