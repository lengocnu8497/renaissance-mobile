//
//  RecoveryInsightsService.swift
//  Renaissance Mobile
//
//  Calls the `generate-recovery-insights` Supabase Edge Function and manages
//  a local UserDefaults cache keyed by procedureId + entryCount.
//  Cache is invalidated automatically when the entry count changes.
//

import Foundation
import Supabase

private let _defaultSupabase: SupabaseClient = supabase

// MARK: - Request Model

private struct InsightsRequest: Encodable {
    let procedureId: String
    let procedureName: String
    let entries: [EntryPayload]

    struct EntryPayload: Encodable {
        let date: String
        let dayNumber: Int
        let notes: String?
        let swellingIndex: Double?
        let bruisingIndex: Double?
        let rednessIndex: Double?
        let overallScore: Double?
    }
}

// MARK: - Edge Function Response (subset — no metadata fields)

private struct InsightsResponse: Decodable {
    let summary: String
    let trend: TrendDirection
    let flags: [InsightFlag]
    let encouragements: [String]
    let nextSteps: String?
}

// MARK: - Service

class RecoveryInsightsService {
    private let supabase: SupabaseClient
    private let cachePrefix = "recovery_insights_"

    init(supabase: SupabaseClient = _defaultSupabase) {
        self.supabase = supabase
    }

    // MARK: - Generate

    /// Calls the edge function and returns a fully populated `RecoveryInsights`.
    /// Saves the result to the local cache automatically.
    func generateInsights(
        entries: [JournalEntry],
        procedureName: String,
        procedureId: String
    ) async throws -> RecoveryInsights {
        let sorted = entries.sorted { $0.dayNumber < $1.dayNumber }

        let payload = InsightsRequest(
            procedureId: procedureId,
            procedureName: procedureName,
            entries: sorted.map {
                InsightsRequest.EntryPayload(
                    date: $0.entryDate,
                    dayNumber: $0.dayNumber,
                    notes: $0.notes,
                    swellingIndex: $0.swellingIndex,
                    bruisingIndex: $0.bruisingIndex,
                    rednessIndex: $0.rednessIndex,
                    overallScore: $0.overallScore
                )
            }
        )

        let response: InsightsResponse = try await supabase.functions
            .invoke(
                "generate-recovery-insights",
                options: FunctionInvokeOptions(body: payload)
            )

        let insights = RecoveryInsights(
            summary: response.summary,
            trend: response.trend,
            flags: response.flags,
            encouragements: response.encouragements,
            nextSteps: response.nextSteps,
            procedureId: procedureId,
            procedureName: procedureName,
            generatedAt: Date(),
            entryCount: entries.count
        )

        saveToCache(insights)
        return insights
    }

    // MARK: - Cache

    /// Returns cached insights if the entry count matches (i.e., no new entries since last generation).
    func fetchCached(procedureId: String, currentEntryCount: Int) -> RecoveryInsights? {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey(procedureId)),
            let cached = try? JSONDecoder().decode(RecoveryInsights.self, from: data)
        else { return nil }

        // Invalidate if entry count has changed
        return cached.entryCount == currentEntryCount ? cached : nil
    }

    private func saveToCache(_ insights: RecoveryInsights) {
        guard let data = try? JSONEncoder().encode(insights) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(insights.procedureId))
    }

    private func cacheKey(_ procedureId: String) -> String {
        "\(cachePrefix)\(procedureId)"
    }
}
