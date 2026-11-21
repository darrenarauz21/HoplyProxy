import SwiftUI

/// Fila con ícono, título y, opcionalmente, una línea de detalle.
struct NavigationRow: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    var detailKey: LocalizedStringKey?

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(systemName: systemImage, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(titleKey)
                    .font(.body)
                    .foregroundStyle(Theme.text)
                if let detailKey {
                    Text(detailKey)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.tertiaryText)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }
}
