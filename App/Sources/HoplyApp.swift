import SwiftUI

@main
struct HoplyApp: App {
    @StateObject private var controller = AppContainer.makeProxyController()

    var body: some Scene {
        WindowGroup {
            RootView(controller: controller)
        }
    }
}
