import ProxyConfig
import SwiftUI

/// Indica qué hacer en la laptop: la app de escritorio, o la configuración manual en la documentación.
struct SetupLaptopStep: View {
    @ObservedObject var controller: ProxyController

    private var details: ClientConnectionDetails {
        controller.connectionDetails
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("setup.laptop.header")
                .font(Theme.title(.title))
                .foregroundStyle(Theme.text)

            Card {
                HStack(alignment: .top, spacing: 14) {
                    IconBadge(systemName: "laptopcomputer", size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("setup.laptop.desktopApp")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        Text(details.transport == .usb
                            ? LocalizedStringKey("setup.laptop.instruction.usb")
                            : LocalizedStringKey("setup.laptop.instruction.wifi"))
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                if details.transport == .wifi {
                    Divider()
                    CopyField(titleKey: "home.connection.iphoneIP", value: details.proxyHost)
                }
            }

            NavigationLink {
                ClientGuideView(controller: controller)
            } label: {
                NavigationRow(
                    titleKey: "setup.laptop.manual",
                    systemImage: "terminal",
                    detailKey: "setup.laptop.manual.detail"
                )
                .padding(Theme.spacing)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
