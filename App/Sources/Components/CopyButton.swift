import SwiftUI
import UIKit

/// Copia un valor y confirma con una marca durante un instante.
struct CopyButton: View {
    let value: String
    @State private var didCopy = false
    private static let feedbackDuration: UInt64 = 1_500_000_000

    var body: some View {
        Button {
            UIPasteboard.general.string = value
            didCopy = true
            Task {
                try? await Task.sleep(nanoseconds: Self.feedbackDuration)
                didCopy = false
            }
        } label: {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                .font(.body.weight(.medium))
                .foregroundStyle(didCopy ? Theme.success : Theme.accent)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(didCopy ? LocalizedStringKey("common.copied") : LocalizedStringKey("common.copy")))
    }
}
