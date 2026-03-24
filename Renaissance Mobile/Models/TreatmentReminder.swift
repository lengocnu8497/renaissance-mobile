//
//  TreatmentReminder.swift
//  Renaissance Mobile
//

import Foundation

enum TreatmentReminderKind: String, Codable {
    case retreatment  // injectable / skin treatment — repeating maintenance cycle
    case followUp     // surgical post-op appointment
}

struct TreatmentReminder: Identifiable, Codable {
    let id: UUID
    let procedureName: String
    let procedureDate: Date
    let reminderDate: Date
    let notificationIdentifier: String
    let label: String                   // "Next Botox", "1-week check-up"
    let kind: TreatmentReminderKind
    var isActive: Bool
    let createdAt: Date

    init(
        procedureName: String,
        procedureDate: Date,
        reminderDate: Date,
        label: String,
        kind: TreatmentReminderKind
    ) {
        self.id = UUID()
        self.procedureName = procedureName
        self.procedureDate = procedureDate
        self.reminderDate = reminderDate
        self.notificationIdentifier = "rena-treatment-\(UUID().uuidString)"
        self.label = label
        self.kind = kind
        self.isActive = true
        self.createdAt = Date()
    }
}
