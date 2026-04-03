//
//  WeeklyCheckIn.swift
//  Renaissance Mobile
//
//  Represents one scheduled week in a procedure's healing timeline.
//  Synced through the weekly_recovery_reports table in Supabase.
//

import Foundation

struct WeeklyCheckIn: Identifiable, Codable {
    let id: UUID
    let procedureId: String
    let procedureName: String
    let weekNumber: Int
    let scheduledDate: Date          // startDate + (weekNumber - 1) * 7 days
    var completedEntryId: UUID?
    var isCompleted: Bool
    var satisfactionRating: Int?
    var generatedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var notificationIdentifier: String {
        "rena-weekly-\(procedureId)-wk\(weekNumber)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case procedureId = "procedure_id"
        case procedureName = "procedure_name"
        case weekNumber = "week_number"
        case scheduledDate = "scheduled_date"
        case completedEntryId = "completed_entry_id"
        case isCompleted = "is_completed"
        case satisfactionRating = "satisfaction_rating"
        case generatedAt = "generated_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(procedureId: String, procedureName: String, weekNumber: Int, startDate: Date) {
        self.id = UUID()
        self.procedureId = procedureId
        self.procedureName = procedureName
        self.weekNumber = weekNumber
        self.scheduledDate = Calendar.current.date(
            byAdding: .weekOfYear, value: weekNumber - 1, to: startDate
        ) ?? startDate
        self.completedEntryId = nil
        self.isCompleted = false
        self.satisfactionRating = nil
        self.generatedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
