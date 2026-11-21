import UIKit

@MainActor
protocol ScreenAwakeControlling: AnyObject {
    func setKeepsScreenOn(_ enabled: Bool)
}

/// Evita el bloqueo automático de pantalla mientras el proxy está activo,
/// porque iOS suspende la app cuando pasa a segundo plano.
@MainActor
final class ScreenAwakeController: ScreenAwakeControlling {
    func setKeepsScreenOn(_ enabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = enabled
    }
}
