import SwiftUI
import UIKit

/// Paleta compartida con Hoply Desktop (`Desktop/src/Hoply.Desktop/Styles/Palette.axaml`):
/// azul marino profundo con acento azul acero.
enum Theme {
    static let background = Color(light: 0xF4F7FB, dark: 0x1A2230)
    static let raised = Color(light: 0xFFFFFF, dark: 0x232D3D)
    static let border = Color(light: 0xD8E1EC, dark: 0x2F3B4D)
    static let text = Color(light: 0x16202E, dark: 0xE9EFF7)
    static let secondaryText = Color(light: 0x4E5D72, dark: 0xA7B5C7)
    static let tertiaryText = Color(light: 0x7B899C, dark: 0x7E8EA3)
    static let accent = Color(light: 0x3D7FE0, dark: 0x3D7FE0)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0xFFFFFF)
    static let success = Color(light: 0x2F8F5B, dark: 0x7CC79A)
    static let warning = Color(light: 0xB7791F, dark: 0xE3B266)
    static let danger = Color(light: 0xC6473B, dark: 0xE58272)

    static let cornerRadius: CGFloat = 16
    static let spacing: CGFloat = 16

    /// Títulos con serifa, como en la app de escritorio.
    static func title(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }
}

private extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
