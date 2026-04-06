//
//  WeeklySummary.swift
//  Renaissance Mobile
//
//  Per-week AI-generated healing summary. Stored locally by WeeklySummaryService
//  and surfaced in AllInsightsView's weekly breakdown section.
//

import Foundation

struct WeeklyMetricPoint: Codable, Identifiable {
    var id: String { "\(dayNumber)-\(date)" }
    let date: String
    let dayNumber: Int
    let painLevel: Double?
    let swellingLevel: Double?
    let bruisingLevel: Double?
    let rednessLevel: Double?
    let hasPhoto: Bool
}

struct WeeklySummary: Codable {
    var id: String { "\(procedureId)-wk\(weekNumber)" }
    let weekNumber: Int
    let headline: String        // 3–6 word status, e.g. "Swelling significantly reduced"
    let observation: String     // 1–2 sentence narrative for the week
    let improvement: String?    // Most notable positive change, if any
    let concern: String?        // Anything worth watching, if any
    let painTrend: String?
    let swellingStatus: String?
    let bruisingStatus: String?
    let rednessStatus: String?
    let recoveryScore: Int?
    let consistencyRate: Int?
    let alerts: [RecoveryAlert]
    let metricPoints: [WeeklyMetricPoint]
    let scheduledDate: Date?
    let completedEntryId: UUID?
    let isCompleted: Bool
    let satisfactionRating: Int?
    let procedureId: String
    let generatedAt: Date
}
