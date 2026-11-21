import SwiftUI

/// Accesos a la documentación, la actividad y el asistente.
struct HomeLinksSection: View {
    @ObservedObject var controller: ProxyController
    let onShowSetup: () -> Void

    var body: some View {
        Card {
            NavigationLink {
                DocumentationView(controller: controller)
            } label: {
                NavigationRow(titleKey: "docs.title", systemImage: "book")
            }
            .buttonStyle(.plain)

            Divider()

            NavigationLink {
                ActivityLogView(activity: controller.activity)
            } label: {
                NavigationRow(titleKey: "home.activityLog", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(.plain)

            Divider()

            Button(action: onShowSetup) {
                NavigationRow(titleKey: "home.setupAssistant", systemImage: "wand.and.stars")
            }
            .buttonStyle(.plain)
        }
    }
}
