import Foundation
import UserNotifications

@MainActor
protocol RenewalReminderScheduling: AnyObject {
    /// Pide permiso si hace falta y programa el aviso. Devuelve `false` si no hay permiso.
    func schedule(at date: Date) async -> Bool
    func cancel()
}

/// Notificación local que recuerda renovar la firma antes de que la app deje de abrir.
@MainActor
final class RenewalReminderScheduler: RenewalReminderScheduling {
    private static let identifier = "Hoply.signatureRenewal"
    private let center = UNUserNotificationCenter.current()

    func schedule(at date: Date) async -> Bool {
        guard await isAuthorized() else { return false }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "reminder.title")
        content.body = String(localized: "reminder.body")
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }

    private func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}
