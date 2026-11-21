import SwiftUI

/// Tráfico de la sesión actual en tres indicadores.
struct TrafficSection: View {
    @ObservedObject var activity: ProxyActivityStore

    var body: some View {
        HStack(spacing: 10) {
            StatTile(
                titleKey: "home.traffic.download",
                systemImage: "arrow.down",
                value: Text(Int64(clamping: activity.statistics.bytesDownloaded), format: .byteCount(style: .file)),
                detail: rateText(activity.downloadRate)
            )
            StatTile(
                titleKey: "home.traffic.upload",
                systemImage: "arrow.up",
                value: Text(Int64(clamping: activity.statistics.bytesUploaded), format: .byteCount(style: .file)),
                detail: rateText(activity.uploadRate)
            )
            StatTile(
                titleKey: "home.traffic.connections",
                systemImage: "link",
                value: Text(activity.statistics.acceptedConnections, format: .number),
                detail: failuresText
            )
        }
    }

    private func rateText(_ rate: Double) -> Text {
        Text("home.traffic.rate \(Int64(rate.rounded()).formatted(.byteCount(style: .file)))")
    }

    private var failuresText: Text? {
        let failures = activity.statistics.failedConnections
        return failures > 0 ? Text("home.traffic.failures \(failures)") : nil
    }
}

private struct StatTile: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    let value: Text
    let detail: Text?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(titleKey)
            } icon: {
                Image(systemName: systemImage)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.tertiaryText)
            .lineLimit(1)

            value
                .font(.headline)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            (detail ?? Text(verbatim: " "))
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
        }
        .monospacedDigit()
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
