import SwiftUI

/// Superficie redondeada con borde suave que agrupa contenido relacionado.
struct Card<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(Theme.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }
}

/// Título pequeño sobre una tarjeta.
struct SectionLabel: View {
    let titleKey: LocalizedStringKey

    var body: some View {
        Text(titleKey)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.tertiaryText)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
    }
}
