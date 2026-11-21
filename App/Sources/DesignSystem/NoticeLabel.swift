import SwiftUI

/// Aviso breve con ícono: advertencias y errores dentro de una tarjeta.
struct NoticeLabel: View {
    let textKey: LocalizedStringKey
    var systemImage = "exclamationmark.triangle.fill"
    var tint: Color = Theme.warning

    var body: some View {
        Label {
            Text(textKey)
                .foregroundStyle(Theme.text)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
        .font(.footnote)
    }
}
