import SwiftUI

/// Fila completa con un comando o valor largo y su botón de copiar.
struct CopyableCommandRow: View {
    let command: String

    var body: some View {
        HStack {
            Text(verbatim: command)
                .font(.callout.monospaced())
                .textSelection(.enabled)
            Spacer()
            CopyButton(value: command)
        }
    }
}
