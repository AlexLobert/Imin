import Foundation
import UserNotifications

enum ResetNotificationScheduler {
    static let identifier = "iminapp.resetReminder"
    static let leadTime: TimeInterval = 45 * 60

    static func schedule(expiresAt: Date) async {
        let center = UNUserNotificationCenter.current()
        let settings = await notificationSettings(center: center)

        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = await requestAuthorization(center: center)
            if !granted {
                return
            }
        case .denied:
            return
        default:
            break
        }

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let triggerDate = expiresAt.addingTimeInterval(-leadTime)
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Status reset soon"
        content.body = "Just a heads-up — your status will reset soon."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancel() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private static func notificationSettings(center: UNUserNotificationCenter) async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private static func requestAuthorization(center: UNUserNotificationCenter) async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}
