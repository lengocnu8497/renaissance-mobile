//
//  WeeklyCheckInService.swift
//  Renaissance Mobile
//
//  Owns weekly schedule metadata such as expected week count and local reminder
//  notifications. Remote weekly state now lives in weekly_recovery_reports via
//  WeeklySummaryService; the legacy UserDefaults helpers remain only as
//  compatibility fallbacks until they can be removed safely.
//

import Foundation
import UserNotifications

final class WeeklyCheckInService {
    static let shared = WeeklyCheckInService()
    private init() {}

    // MARK: - Keys

    private func storeKey(for procedureId: String) -> String {
        "rena_weekly_checkins_\(procedureId)"
    }
    private func snoozeKey(for procedureId: String) -> String {
        "rena_checkin_snooze_\(procedureId)"
    }

    // MARK: - Schedule Generation

    /// Number of weeks to track — based on expected recovery duration.
    func weekCount(for procedureName: String) -> Int {
        let config = ProcedureReminderConfig.config(for: procedureName)
        switch config.category {
        case .cosmeticSurgery: return 12
        case .skinTreatment:   return 4
        case .injectable:      return 4
        case .other:           return 6
        }
    }

    func generateCheckIns(
        procedureId: String,
        procedureName: String,
        startDate: Date
    ) -> [WeeklyCheckIn] {
        let total = weekCount(for: procedureName)
        return (1...total).map {
            WeeklyCheckIn(
                procedureId: procedureId,
                procedureName: procedureName,
                weekNumber: $0,
                startDate: startDate
            )
        }
    }

    // MARK: - Persistence

    func loadCheckIns(for procedureId: String) -> [WeeklyCheckIn] {
        guard let data = UserDefaults.standard.data(forKey: storeKey(for: procedureId)),
              let checkIns = try? JSONDecoder().decode([WeeklyCheckIn].self, from: data)
        else { return [] }
        return checkIns
    }

    /// Upserts check-ins — preserves existing completion state.
    func saveCheckIns(_ checkIns: [WeeklyCheckIn]) {
        let grouped = Dictionary(grouping: checkIns, by: \.procedureId)
        for (procedureId, incoming) in grouped {
            var existing = loadCheckIns(for: procedureId)
            for checkIn in incoming {
                existing.removeAll { $0.weekNumber == checkIn.weekNumber }
                existing.append(checkIn)
            }
            persist(existing.sorted { $0.weekNumber < $1.weekNumber }, for: procedureId)
        }
    }

    func markCompleted(weekNumber: Int, procedureId: String, entryId: UUID) {
        var all = loadCheckIns(for: procedureId)
        guard let idx = all.firstIndex(where: { $0.weekNumber == weekNumber }) else { return }
        all[idx].isCompleted = true
        all[idx].completedEntryId = entryId
        persist(all, for: procedureId)
        // Cancel the notification since user has completed it
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [all[idx].notificationIdentifier]
        )
    }

    // MARK: - Queries

    /// First incomplete check-in whose date has passed (respects 24h snooze).
    func pendingCheckIn(for procedureId: String) -> WeeklyCheckIn? {
        if isSnoozed(procedureId: procedureId) { return nil }
        return firstIncompleteCheckIn(for: procedureId)
    }

    /// First incomplete check-in whose date has passed — ignores snooze.
    /// Use for auto-fulfillment after an entry is saved.
    func firstIncompleteCheckIn(for procedureId: String) -> WeeklyCheckIn? {
        loadCheckIns(for: procedureId)
            .filter { !$0.isCompleted && $0.scheduledDate <= Date() }
            .sorted { $0.weekNumber < $1.weekNumber }
            .first
    }

    func snooze(procedureId: String) {
        let until = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date()
        UserDefaults.standard.set(until, forKey: snoozeKey(for: procedureId))
    }

    private func isSnoozed(procedureId: String) -> Bool {
        guard let until = UserDefaults.standard.object(forKey: snoozeKey(for: procedureId)) as? Date
        else { return false }
        return until > Date()
    }

    // MARK: - Notifications

    func scheduleNotifications(for checkIns: [WeeklyCheckIn], procedureName: String) async {
        guard await TreatmentNotificationService.shared.requestPermissionIfNeeded() else { return }
        let center = UNUserNotificationCenter.current()
        for checkIn in checkIns where !checkIn.isCompleted && checkIn.scheduledDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Week \(checkIn.weekNumber) Recovery Report — \(procedureName)"
            content.body = "Keep logging daily so your weekly recovery report stays accurate and useful."
            content.sound = .default
            content.userInfo = [
                "procedureName": procedureName,
                "weekNumber": checkIn.weekNumber,
                "procedureId": checkIn.procedureId
            ]
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: checkIn.scheduledDate)
            comps.hour = 9
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: checkIn.notificationIdentifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    // MARK: - Private

    private func persist(_ checkIns: [WeeklyCheckIn], for procedureId: String) {
        if let data = try? JSONEncoder().encode(checkIns) {
            UserDefaults.standard.set(data, forKey: storeKey(for: procedureId))
        }
    }
}
