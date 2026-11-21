import Foundation
import ProxyConfig

/// Conoce la caducidad de la firma y programa o cancela el recordatorio de renovación.
@MainActor
final class SignatureMonitor: ObservableObject {
    let expirationDate: Date?
    /// `false` si el usuario activó el recordatorio pero negó el permiso de notificaciones.
    @Published private(set) var isReminderAuthorized = true

    private let scheduler: RenewalReminderScheduling
    private var reminderTask: Task<Void, Never>?

    init(expirationDate: Date?, scheduler: RenewalReminderScheduling) {
        self.expirationDate = expirationDate
        self.scheduler = scheduler
    }

    func status(at date: Date) -> SignatureExpiryStatus {
        SignatureExpiryStatus.evaluate(expirationDate: expirationDate, now: date)
    }

    func applyReminder(enabled: Bool) {
        reminderTask?.cancel()
        guard enabled,
              let expirationDate,
              let reminderDate = SignatureExpiryStatus.reminderDate(forExpiration: expirationDate, now: Date()) else {
            scheduler.cancel()
            isReminderAuthorized = true
            return
        }
        reminderTask = Task { [weak self, scheduler] in
            let isScheduled = await scheduler.schedule(at: reminderDate)
            guard !Task.isCancelled else { return }
            self?.isReminderAuthorized = isScheduled
        }
    }
}
