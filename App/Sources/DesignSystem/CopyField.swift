import SwiftUI

/// Dato que la laptop necesita: título, valor en monoespaciada y botón de copiar.
struct CopyField: View {
    let titleKey: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(titleKey)
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
                Text(verbatim: value)
                    .font(.callout.monospaced())
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            CopyButton(value: value)
        }
    }
}
