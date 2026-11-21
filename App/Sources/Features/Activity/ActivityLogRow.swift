import SwiftUI

struct ActivityLogRow: View {
    let entry: ActivityLogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: entry.kind.symbolName)
                .foregroundStyle(entry.kind.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.kind.messageKey)
                Text(entry.date, format: .dateTime.hour().minute().second())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let address = entry.kind.clientAddress {
                CopyButton(value: address)
            }
        }
    }
}
