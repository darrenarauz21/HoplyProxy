import SwiftUI

/// Muestra el asistente en el primer uso y la pantalla principal después.
struct RootView: View {
    @ObservedObject var controller: ProxyController
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        HomeView(controller: controller)
            .tint(Theme.accent)
            .fullScreenCover(isPresented: isShowingInitialSetup) {
                SetupFlowView(controller: controller)
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    controller.refreshNetwork()
                }
            }
    }

    /// El asistente se cierra al completarlo, no deslizando.
    private var isShowingInitialSetup: Binding<Bool> {
        Binding(get: { !controller.hasCompletedSetup }, set: { _ in })
    }
}
