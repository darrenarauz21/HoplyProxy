import ProxyConfig
import SwiftUI

struct ClientGuideView: View {
    @ObservedObject var controller: ProxyController
    @AppStorage(ClientPlatform.storageKey) private var platform: ClientPlatform = .windows

    var body: some View {
        List {
            Section {
                ClientPlatformPicker(selection: $platform)
            } header: {
                Text("guide.platform")
            }

            if controller.isWiFiUnavailable {
                Section {
                    Text("home.connection.wifiUnavailable")
                        .foregroundStyle(Theme.warning)
                }
            }

            ClientGuideStepsSection(
                steps: ClientSetupGuide.steps(for: platform, details: controller.connectionDetails)
            )
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("guide.title")
        .onAppear(perform: controller.refreshNetwork)
    }
}
