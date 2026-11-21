import SwiftUI

/// Píldora de ancho completo con el color de acento.
struct PrimaryButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isDestructive ? Theme.danger : Theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(isDestructive ? Theme.danger.opacity(0.14) : Theme.accent, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Capsule())
    }
}

/// Botón de texto discreto para acciones secundarias.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 40)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}
