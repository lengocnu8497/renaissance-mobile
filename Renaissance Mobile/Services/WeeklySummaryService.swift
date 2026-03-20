//
//  WeeklySummaryService.swift
//  Renaissance Mobile
//
//  Calls the `generate-weekly-summary` Supabase Edge Function and manages
//  a local UserDefaults cache keyed by procedureId + weekNumber.
//

import Foundation
import Supabase

private let _defaultSupabase: SupabaseClient = supabase

// MARK: - Request / Response

private struct WeeklySummaryRequest: Encodable {
    let procedureId: String
    let procedureName: String
    let weekNumber: Int
    let entries: [EntryPayload]

    struct EntryPayload: Encodable {
        let date: String
        let dayNumber: Int
        let notes: String?
        let bruisingLevel: Double?
        let swellingLevel: Double?
        let rednessLevel: Double?
    }
}

private struct WeeklySummaryResponse: Decodable {
    let weekNumber: Int
    let headline: String
    let observation: String
    let improvement: String?
    let concern: String?
}

// MARK: - Service

class WeeklySummaryService {
    private let supabase: SupabaseClient
    private let cachePrefix = "weekly_summary_"

    init(supabase: SupabaseClient = _defaultSupabase) {
        self.supabase = supabase
    }

    // MARK: - Generate

    /// Generates a weekly summary for entries that fall within the given week number's date range.
    /// Falls back to all entries for the procedure if no entries exist in the exact week window.
    func generateSummary(
        procedureId: String,
        procedureName: String,
        weekNumber: Int,
        entries: [JournalEntry]
    ) async throws -> WeeklySummary {
        let startDay = (weekNumber - 1) * 7
        let endDay   = weekNumber * 7 - 1
        let weekEntries = entries.filter { $0.dayNumber >= startDay && $0.dayNumber <= endDay }
        let target = weekEntries.isEmpty ? entries : weekEntries

        let payload = WeeklySummaryRequest(
            procedureId: procedureId,
            procedureName: procedureName,
            weekNumber: weekNumber,
            entries: target
                .sorted { $0.dayNumber < $1.dayNumber }
                .map {
                    WeeklySummaryRequest.EntryPayload(
                        date: $0.entryDate,
                        dayNumber: $0.dayNumber,
                        notes: $0.notes,
                        bruisingLevel: $0.bruisingLevel,
                        swellingLevel: $0.swellingLevel,
                        rednessLevel: $0.rednessLevel
                    )
                }
        )

        let response: WeeklySummaryResponse = try await supabase.functions
            .invoke(
                "generate-weekly-summary",
                options: FunctionInvokeOptions(body: payload)
            )

        let summary = WeeklySummary(
            weekNumber: response.weekNumber,
            headline: response.headline,
            observation: response.observation,
            improvement: response.improvement,
            concern: response.concern,
            procedureId: procedureId,
            generatedAt: Date()
        )
        saveToCache(summary)
        return summary
    }

    // MARK: - Cache

    func fetchCached(procedureId: String, weekNumber: Int) -> WeeklySummary? {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey(procedureId, weekNumber)),
            let cached = try? JSONDecoder().decode(WeeklySummary.self, from: data)
        else { return nil }
        return cached
    }

    private func saveToCache(_ summary: WeeklySummary) {
        guard let data = try? JSONEncoder().encode(summary) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(summary.procedureId, summary.weekNumber))
    }

    private func cacheKey(_ procedureId: String, _ weekNumber: Int) -> String {
        "\(cachePrefix)\(procedureId)_wk\(weekNumber)"
    }
}
