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
        let painLevel: Double?
        let bruisingLevel: Double?
        let swellingLevel: Double?
        let rednessLevel: Double?
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
                    painLevel: $0.painLevel,
                    bruisingLevel: $0.bruisingLevel,
                    swellingLevel: $0.swellingLevel,
                    rednessLevel: $0.rednessLevel
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
            let cached = ProtectedLocalStore.load(RecoveryInsights.self, forKey: cacheKey(procedureId))
        else { return nil }

        // Invalidate if entry count has changed
        return cached.entryCount == currentEntryCount ? cached : nil
    }

    private func saveToCache(_ insights: RecoveryInsights) {
        try? ProtectedLocalStore.save(insights, forKey: cacheKey(insights.procedureId))
    }

    /// Returns the most recently generated cached insight across all procedures.
    /// Does not validate entry count — suitable for context injection only.
    func fetchMostRecentCached() -> RecoveryInsights? {
        ProtectedLocalStore.loadAll(RecoveryInsights.self, withPrefix: cachePrefix)
            .max(by: { $0.generatedAt < $1.generatedAt })
    }

    private func cacheKey(_ procedureId: String) -> String {
        "\(cachePrefix)\(procedureId)"
    }
}

extension RecoveryInsightsService: RecoveryInsightsServiceProtocol {}
