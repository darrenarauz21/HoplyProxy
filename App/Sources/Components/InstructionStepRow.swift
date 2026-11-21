import SwiftUI

struct InstructionStepRow: View {
    let number: Int
    let textKey: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(number, format: .number)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 16)
            Text(textKey)
        }
    }
}
