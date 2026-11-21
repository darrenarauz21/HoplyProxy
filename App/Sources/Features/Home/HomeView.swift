import SwiftUI

struct HomeView: View {
    @ObservedObject var controller: ProxyController
    @State private var isShowingSettings = false
    @State private var isShowingSetup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    StatusSection(
                        state: controller.state,
                        startIssues: controller.startIssues,
                        isCellularUnavailable: controller.isCellularUnavailable,
                        keepsRunningInBackground: controller.settings.keepsRunningInBackground,
                        onToggle: controller.toggle
                    )

                    TrafficSection(activity: controller.activity)

                    ConnectionSection(
                        details: controller.connectionDetails,
                        isWiFiUnavailable: controller.isWiFiUnavailable
                    )

                    SignatureSection(signature: controller.signature)

                    HomeLinksSection(controller: controller) {
                        isShowingSetup = true
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(controller: controller)
            }
            .sheet(isPresented: $isShowingSetup) {
                SetupFlowView(controller: controller)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .interpolation(.none)
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
            Text("home.title")
                .font(Theme.title(.title))
                .foregroundStyle(Theme.text)
            Spacer()
            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("settings.title"))
        }
        .padding(.top, 8)
    }
}
