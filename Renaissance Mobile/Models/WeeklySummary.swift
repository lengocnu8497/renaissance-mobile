//
//  WeeklySummary.swift
//  Renaissance Mobile
//
//  Per-week AI-generated healing summary. Stored locally by WeeklySummaryService
//  and surfaced in AllInsightsView's weekly breakdown section.
//

import Foundation

struct WeeklySummary: Codable {
    let weekNumber: Int
    let headline: String        // 3–6 word status, e.g. "Swelling significantly reduced"
    let observation: String     // 1–2 sentence narrative for the week
    let improvement: String?    // Most notable positive change, if any
    let concern: String?        // Anything worth watching, if any
    let procedureId: String
    let generatedAt: Date
}
