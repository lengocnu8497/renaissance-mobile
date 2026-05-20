//
//  NotificationModeService.swift
//  Renaissance Mobile
//

import Foundation
import UserNotifications

final class NotificationModeService {
    static let shared = NotificationModeService()
    private init() {}

    private static let modeKey    = "rena.notificationMode"
    private static let hourKey    = "rena.notificationHour"
    private static let minuteKey  = "rena.notificationMinute"
    private static let weekdayKey = "rena.notificationWeekday"
    private static let dailyId    = "rena.recovery.checkin.daily"
    private static let weeklyId   = "rena.recovery.checkin.weekly"

    var current: NotificationMode {
        let raw = UserDefaults.standard.string(forKey: Self.modeKey) ?? ""
        return NotificationMode(rawValue: raw) ?? .daily
    }

    /// Persist mode + schedule params, reschedule notifications, and sync to Supabase.
    func apply(
        _ mode: NotificationMode,
        hour: Int    = 9,
        minute: Int  = 0,
        weekday: Int = 2,
        profileService: UserProfileService
    ) async {
        let ud = UserDefaults.standard
        ud.set(mode.rawValue, forKey: Self.modeKey)
        ud.set(hour,          forKey: Self.hourKey)
        ud.set(minute,        forKey: Self.minuteKey)
        ud.set(weekday,       forKey: Self.weekdayKey)

        await reschedule(for: mode, hour: hour, minute: minute, weekday: weekday)

        try? await profileService.updateMetadata([
            "notification_mode":    AnyCodable(mode.rawValue),
            "notification_hour":    AnyCodable(hour),
            "notification_minute":  AnyCodable(minute),
            "notification_weekday": AnyCodable(weekday)
        ])
    }

    /// Hydrate local UserDefaults from a freshly-fetched profile (call on app load).
    func loadFromProfile(_ profile: UserProfile) {
        guard let meta = profile.metadata else { return }
        let ud = UserDefaults.standard
        if let raw = meta["notification_mode"]?.value as? String, NotificationMode(rawValue: raw) != nil {
            ud.set(raw, forKey: Self.modeKey)
        }
        if let h = meta["notification_hour"]?.value as? Int    { ud.set(h, forKey: Self.hourKey) }
        if let m = meta["notification_minute"]?.value as? Int  { ud.set(m, forKey: Self.minuteKey) }
        if let w = meta["notification_weekday"]?.value as? Int { ud.set(w, forKey: Self.weekdayKey) }
    }

    // MARK: - Private scheduling

    private func reschedule(for mode: NotificationMode, hour: Int, minute: Int, weekday: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyId, Self.weeklyId])

        guard mode != .off else { return }

        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }

        switch mode {
        case .daily:
            schedule(id: Self.dailyId,
                     title: "How's your recovery going?",
                     body: "Tap to log today.",
                     hour: hour, minute: minute, weekday: nil)
        case .weekly:
            schedule(id: Self.weeklyId,
                     title: "Weekly check-in time.",
                     body: "Log how you've been feeling this week.",
                     hour: hour, minute: minute, weekday: weekday)
        case .off:
            break
        }
    }

    private func schedule(id: String, title: String, body: String, hour: Int, minute: Int, weekday: Int?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        var components = DateComponents()
        components.hour   = hour
        components.minute = minute
        if let weekday { components.weekday = weekday }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
