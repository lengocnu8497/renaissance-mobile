//
//  TreatmentNotificationService.swift
//  Renaissance Mobile
//

import Foundation
import UserNotifications

final class TreatmentNotificationService {
    static let shared = TreatmentNotificationService()
    private init() {}

    // MARK: - Permission

    /// Requests notification permission if not yet determined.
    /// Returns true if permission is granted (or was already granted).
    @discardableResult
    func requestPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default: return false
        }
    }

    // MARK: - Schedule

    /// Schedules a local notification for the given reminder.
    /// Silently no-ops if permission is denied or the reminder date is in the past.
    func schedule(_ reminder: TreatmentReminder) async {
        guard reminder.reminderDate > Date() else { return }
        guard await requestPermissionIfNeeded() else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = [
            "procedureName": reminder.procedureName,
            "reminderId": reminder.id.uuidString
        ]

        switch reminder.kind {
        case .retreatment:
            content.title = "Time for your next \(reminder.procedureName)"
            content.body = "Your results are ready for a refresh. Book your next appointment with Rena."
        case .followUp:
            content.title = "\(reminder.label) — \(reminder.procedureName)"
            content.body = "Don't skip your post-op check-up. Book your appointment to stay on track."
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: reminder.reminderDate)
        components.hour = 10
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: reminder.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancel

    func cancel(identifier: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
