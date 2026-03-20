//
//  TreatmentReminderStore.swift
//  Renaissance Mobile
//

import Foundation

final class TreatmentReminderStore {
    static let shared = TreatmentReminderStore()
    private let key = "rena_treatment_reminders"
    private init() {}

    // MARK: - Read

    func loadAll() -> [TreatmentReminder] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let reminders = try? JSONDecoder().decode([TreatmentReminder].self, from: data)
        else { return [] }
        return reminders
    }

    /// Active reminders whose reminder date is still in the future, sorted soonest-first.
    func activeUpcoming() -> [TreatmentReminder] {
        loadAll()
            .filter { $0.isActive && $0.reminderDate > Date() }
            .sorted { $0.reminderDate < $1.reminderDate }
    }

    // MARK: - Write

    func save(_ reminder: TreatmentReminder) {
        var all = loadAll()
        all.removeAll { $0.id == reminder.id }
        all.append(reminder)
        persist(all)
    }

    func saveAll(_ reminders: [TreatmentReminder]) {
        var all = loadAll()
        for reminder in reminders {
            all.removeAll { $0.id == reminder.id }
            all.append(reminder)
        }
        persist(all)
    }

    // MARK: - Delete

    func delete(id: UUID) {
        var all = loadAll()
        if let reminder = all.first(where: { $0.id == id }) {
            TreatmentNotificationService.shared.cancel(identifier: reminder.notificationIdentifier)
        }
        all.removeAll { $0.id == id }
        persist(all)
    }

    // MARK: - Maintenance

    /// Marks reminders whose date has passed as inactive. Call on app launch.
    func pruneExpired() {
        var all = loadAll()
        let now = Date()
        var changed = false
        for i in all.indices where all[i].isActive && all[i].reminderDate <= now {
            all[i].isActive = false
            changed = true
        }
        if changed { persist(all) }
    }

    // MARK: - Persistence

    private func persist(_ reminders: [TreatmentReminder]) {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
