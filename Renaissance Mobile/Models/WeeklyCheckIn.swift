//
//  WeeklyCheckIn.swift
//  Renaissance Mobile
//
//  Represents one scheduled week in a procedure's healing timeline.
//  Stored locally per-procedure in UserDefaults by WeeklyCheckInService.
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
    let notificationIdentifier: String
    let createdAt: Date

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
        self.notificationIdentifier = "rena-weekly-\(procedureId)-wk\(weekNumber)"
        self.createdAt = Date()
    }
}
