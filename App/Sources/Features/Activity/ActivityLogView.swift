import SwiftUI

/// Sucesos recientes del proxy, sin destinos ni contenido.
struct ActivityLogView: View {
    @ObservedObject var activity: ProxyActivityStore

    var body: some View {
        List {
            if activity.entries.isEmpty {
                Text("log.empty")
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(activity.entries) { entry in
                        ActivityLogRow(entry: entry)
                    }
                } footer: {
                    Text("log.footer")
                }
            }
        }
        .navigationTitle("log.title")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("log.clear", action: activity.clearLog)
                    .disabled(activity.entries.isEmpty)
            }
        }
    }
}
