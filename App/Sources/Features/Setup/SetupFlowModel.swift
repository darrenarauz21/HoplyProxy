import Foundation
import ProxyConfig

/// Asistente de tres pasos: modo de conexión, preparar la laptop y confirmación.
@MainActor
final class SetupFlowModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case transport
        case laptop
        case summary
    }

    @Published private(set) var step: Step = .transport
    @Published var transport: TransportMode
    @Published private(set) var issues: [ProxySettingsIssue] = []
    @Published private(set) var didFailToPersist = false

    let controller: ProxyController

    init(controller: ProxyController) {
        self.controller = controller
        self.transport = controller.settings.transport
    }

    var canGoBack: Bool {
        step != .transport
    }

    var stepNumber: Int {
        step.rawValue + 1
    }

    var stepCount: Int {
        Step.allCases.count
    }

    func goBack() {
        step = Step(rawValue: step.rawValue - 1) ?? .transport
    }

    func goForward() {
        if step == .transport {
            guard applyTransport() else { return }
        }
        step = Step(rawValue: step.rawValue + 1) ?? .summary
    }

    /// Marca el asistente como completado y, si se pide, inicia el proxy.
    func finish(startingProxy: Bool) {
        controller.completeSetup()
        if startingProxy {
            controller.start()
        }
    }

    /// Guarda el modo elegido. En Wi-Fi sin lista de clientes autoriza la red actual del iPhone.
    private func applyTransport() -> Bool {
        controller.refreshNetwork()
        var settings = controller.settings
        settings.transport = transport
        if transport == .wifi, settings.allowedClients.isEmpty, let subnet = controller.wifiNetwork?.subnet {
            settings.allowedClients = [subnet.description]
        }

        do {
            try controller.save(settings: settings, password: controller.password)
            issues = []
            didFailToPersist = false
            return true
        } catch let error as ProxySettingsValidationError {
            issues = error.issues
            return false
        } catch {
            didFailToPersist = true
            return false
        }
    }
}
