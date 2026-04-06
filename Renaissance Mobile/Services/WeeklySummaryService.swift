//
//  WeeklySummaryService.swift
//  Renaissance Mobile
//
//  Uses the weekly_recovery_reports table for synced weekly state and calls the
//  generate-weekly-summary Edge Function to create backend-owned reports,
//  scoring, and alerts.
//

import Foundation
import Supabase

private let _defaultSupabase: SupabaseClient = supabase

private struct WeeklySummaryRequest: Encodable {
    let procedureId: String
    let procedureName: String
    let weekNumber: Int
    let scheduledDate: String
    let completedEntryId: String?
    let entries: [EntryPayload]

    struct EntryPayload: Encodable {
        let date: String
        let dayNumber: Int
        let notes: String?
        let painLevel: Double?
        let bruisingLevel: Double?
        let swellingLevel: Double?
        let rednessLevel: Double?
        let hasPhoto: Bool
    }
}

private struct WeeklySummaryResponse: Decodable {
    let weekNumber: Int
    let headline: String
    let observation: String
    let improvement: String?
    let concern: String?
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
    let isCompleted: Bool?
    let satisfactionRating: Int?
    let generatedAt: Date?
}

private struct WeeklyReportRow: Codable {
    let id: UUID
    let userId: UUID
    let procedureId: String
    let procedureName: String
    let weekNumber: Int
    let scheduledDate: Date
    let completedEntryId: UUID?
    let isCompleted: Bool
    let satisfactionRating: Int?
    let headline: String?
    let observation: String?
    let improvement: String?
    let concern: String?
    let painTrend: String?
    let swellingStatus: String?
    let bruisingStatus: String?
    let rednessStatus: String?
    let recoveryScore: Int?
    let consistencyRate: Int?
    let alerts: [RecoveryAlert]
    let metricPoints: [WeeklyMetricPoint]
    let generatedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case procedureId = "procedure_id"
        case procedureName = "procedure_name"
        case weekNumber = "week_number"
        case scheduledDate = "scheduled_date"
        case completedEntryId = "completed_entry_id"
        case isCompleted = "is_completed"
        case satisfactionRating = "satisfaction_rating"
        case headline
        case observation
        case improvement
        case concern
        case painTrend = "pain_trend"
        case swellingStatus = "swelling_status"
        case bruisingStatus = "bruising_status"
        case rednessStatus = "redness_status"
        case recoveryScore = "recovery_score"
        case consistencyRate = "consistency_rate"
        case alerts
        case metricPoints = "metric_points"
        case generatedAt = "generated_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        procedureId = try container.decode(String.self, forKey: .procedureId)
        procedureName = try container.decode(String.self, forKey: .procedureName)
        weekNumber = try container.decode(Int.self, forKey: .weekNumber)
        scheduledDate = try Self.decodeFlexibleDate(from: container, forKey: .scheduledDate)
        completedEntryId = try container.decodeIfPresent(UUID.self, forKey: .completedEntryId)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        satisfactionRating = try container.decodeIfPresent(Int.self, forKey: .satisfactionRating)
        headline = try container.decodeIfPresent(String.self, forKey: .headline)
        observation = try container.decodeIfPresent(String.self, forKey: .observation)
        improvement = try container.decodeIfPresent(String.self, forKey: .improvement)
        concern = try container.decodeIfPresent(String.self, forKey: .concern)
        painTrend = try container.decodeIfPresent(String.self, forKey: .painTrend)
        swellingStatus = try container.decodeIfPresent(String.self, forKey: .swellingStatus)
        bruisingStatus = try container.decodeIfPresent(String.self, forKey: .bruisingStatus)
        rednessStatus = try container.decodeIfPresent(String.self, forKey: .rednessStatus)
        recoveryScore = try container.decodeIfPresent(Int.self, forKey: .recoveryScore)
        consistencyRate = try container.decodeIfPresent(Int.self, forKey: .consistencyRate)
        alerts = try container.decodeIfPresent([RecoveryAlert].self, forKey: .alerts) ?? []
        metricPoints = try container.decodeIfPresent([WeeklyMetricPoint].self, forKey: .metricPoints) ?? []
        generatedAt = try Self.decodeFlexibleDateIfPresent(from: container, forKey: .generatedAt)
        createdAt = try Self.decodeFlexibleDate(from: container, forKey: .createdAt)
        updatedAt = try Self.decodeFlexibleDate(from: container, forKey: .updatedAt)
    }

    private static func decodeFlexibleDate(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Date {
        if let timestamp = try? container.decode(Date.self, forKey: key) {
            return timestamp
        }

        let raw = try container.decode(String.self, forKey: key)
        if let parsed = flexibleDate(from: raw) {
            return parsed
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Invalid date format: \(raw)"
        )
    }

    private static func decodeFlexibleDateIfPresent(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Date? {
        if try container.decodeNil(forKey: key) {
            return nil
        }
        return try decodeFlexibleDate(from: container, forKey: key)
    }

    private static func flexibleDate(from raw: String) -> Date? {
        if let dateOnly = dateOnlyFormatter.date(from: raw) {
            return dateOnly
        }
        if let isoWithFractional = iso8601Fractional.date(from: raw) {
            return isoWithFractional
        }
        if let isoPlain = iso8601Plain.date(from: raw) {
            return isoPlain
        }
        return timestampFormatter.date(from: raw)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct WeeklyReportInsert: Encodable {
    let userId: UUID
    let procedureId: String
    let procedureName: String
    let weekNumber: Int
    let scheduledDate: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case procedureId = "procedure_id"
        case procedureName = "procedure_name"
        case weekNumber = "week_number"
        case scheduledDate = "scheduled_date"
    }
}

private struct WeeklyReportCompletionUpdate: Encodable {
    let completedEntryId: String
    let isCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case completedEntryId = "completed_entry_id"
        case isCompleted = "is_completed"
    }
}

private struct WeeklyReportSatisfactionUpdate: Encodable {
    let satisfactionRating: Int

    enum CodingKeys: String, CodingKey {
        case satisfactionRating = "satisfaction_rating"
    }
}

final class WeeklySummaryService {
    private let supabase: SupabaseClient
    private let cachePrefix = "weekly_summary_"

    init(supabase: SupabaseClient = _defaultSupabase) {
        self.supabase = supabase
    }

    func bootstrapWeeks(
        procedureId: String,
        procedureName: String,
        startDate: Date
    ) async throws -> [WeeklyCheckIn] {
        guard let userId = supabase.auth.currentUser?.id else {
            throw NSError(domain: "WeeklySummaryService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let existing = try await fetchWeeklyStates(procedureId: procedureId)
        if !existing.isEmpty { return existing }

        let totalWeeks = WeeklyCheckInService.shared.weekCount(for: procedureName)
        let formatter = Self.dateFormatter
        let rows = (1...totalWeeks).map { weekNumber in
            WeeklyReportInsert(
                userId: userId,
                procedureId: procedureId,
                procedureName: procedureName,
                weekNumber: weekNumber,
                scheduledDate: formatter.string(
                    from: Calendar.current.date(byAdding: .weekOfYear, value: weekNumber - 1, to: startDate) ?? startDate
                )
            )
        }

        _ = try await supabase.database
            .from("weekly_recovery_reports")
            .upsert(rows, onConflict: "user_id,procedure_id,week_number")
            .execute()

        return try await fetchWeeklyStates(procedureId: procedureId)
    }

    func fetchWeeklyStates(procedureId: String) async throws -> [WeeklyCheckIn] {
        let rows: [WeeklyReportRow] = try await supabase.database
            .from("weekly_recovery_reports")
            .select()
            .eq("procedure_id", value: procedureId)
            .order("week_number", ascending: true)
            .execute()
            .value

        return rows.map {
            WeeklyCheckIn(
                id: $0.id,
                procedureId: $0.procedureId,
                procedureName: $0.procedureName,
                weekNumber: $0.weekNumber,
                scheduledDate: $0.scheduledDate,
                completedEntryId: $0.completedEntryId,
                isCompleted: $0.isCompleted,
                satisfactionRating: $0.satisfactionRating,
                generatedAt: $0.generatedAt,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        }
    }

    func fetchRemoteSummaries(procedureId: String) async throws -> [WeeklySummary] {
        let rows: [WeeklyReportRow] = try await supabase.database
            .from("weekly_recovery_reports")
            .select()
            .eq("procedure_id", value: procedureId)
            .order("week_number", ascending: true)
            .execute()
            .value

        let summaries = rows.compactMap(summary(from:))
        for summary in summaries { saveToCache(summary) }
        return summaries
    }

    func generateSummary(
        procedureId: String,
        procedureName: String,
        weekNumber: Int,
        scheduledDate: Date,
        completedEntryId: UUID?,
        entries: [JournalEntry]
    ) async throws -> WeeklySummary {
        let startDay = (weekNumber - 1) * 7
        let endDay = weekNumber * 7 - 1
        let weekEntries = entries.filter { $0.dayNumber >= startDay && $0.dayNumber <= endDay }
        let target = weekEntries.isEmpty ? entries : weekEntries

        let payload = WeeklySummaryRequest(
            procedureId: procedureId,
            procedureName: procedureName,
            weekNumber: weekNumber,
            scheduledDate: Self.dateFormatter.string(from: scheduledDate),
            completedEntryId: completedEntryId?.uuidString,
            entries: target.sorted { $0.dayNumber < $1.dayNumber }.map {
                WeeklySummaryRequest.EntryPayload(
                    date: $0.entryDate,
                    dayNumber: $0.dayNumber,
                    notes: $0.notes,
                    painLevel: $0.painLevel,
                    bruisingLevel: $0.bruisingLevel,
                    swellingLevel: $0.swellingLevel,
                    rednessLevel: $0.rednessLevel,
                    hasPhoto: $0.photoUrl != nil || $0.photoPath != nil
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
            painTrend: response.painTrend,
            swellingStatus: response.swellingStatus,
            bruisingStatus: response.bruisingStatus,
            rednessStatus: response.rednessStatus,
            recoveryScore: response.recoveryScore,
            consistencyRate: response.consistencyRate,
            alerts: response.alerts,
            metricPoints: response.metricPoints,
            scheduledDate: response.scheduledDate ?? scheduledDate,
            completedEntryId: response.completedEntryId ?? completedEntryId,
            isCompleted: response.isCompleted ?? (completedEntryId != nil),
            satisfactionRating: response.satisfactionRating,
            procedureId: procedureId,
            generatedAt: response.generatedAt ?? Date()
        )
        saveToCache(summary)
        return summary
    }

    func updateCompletion(
        procedureId: String,
        weekNumber: Int,
        entryId: UUID
    ) async throws {
        _ = try await supabase.database
            .from("weekly_recovery_reports")
            .update(
                WeeklyReportCompletionUpdate(
                    completedEntryId: entryId.uuidString,
                    isCompleted: true
                )
            )
            .eq("procedure_id", value: procedureId)
            .eq("week_number", value: weekNumber)
            .execute()
    }

    func updateSatisfaction(
        procedureId: String,
        weekNumber: Int,
        rating: Int
    ) async throws {
        _ = try await supabase.database
            .from("weekly_recovery_reports")
            .update(WeeklyReportSatisfactionUpdate(satisfactionRating: rating))
            .eq("procedure_id", value: procedureId)
            .eq("week_number", value: weekNumber)
            .execute()
    }

    func fetchCached(procedureId: String, weekNumber: Int) -> WeeklySummary? {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey(procedureId, weekNumber)),
            let cached = try? JSONDecoder().decode(WeeklySummary.self, from: data)
        else { return nil }
        return cached
    }

    private func summary(from row: WeeklyReportRow) -> WeeklySummary? {
        guard let headline = row.headline, let observation = row.observation, let generatedAt = row.generatedAt else {
            return nil
        }
        return WeeklySummary(
            weekNumber: row.weekNumber,
            headline: headline,
            observation: observation,
            improvement: row.improvement,
            concern: row.concern,
            painTrend: row.painTrend,
            swellingStatus: row.swellingStatus,
            bruisingStatus: row.bruisingStatus,
            rednessStatus: row.rednessStatus,
            recoveryScore: row.recoveryScore,
            consistencyRate: row.consistencyRate,
            alerts: row.alerts,
            metricPoints: row.metricPoints,
            scheduledDate: row.scheduledDate,
            completedEntryId: row.completedEntryId,
            isCompleted: row.isCompleted,
            satisfactionRating: row.satisfactionRating,
            procedureId: row.procedureId,
            generatedAt: generatedAt
        )
    }

    private func saveToCache(_ summary: WeeklySummary) {
        guard let data = try? JSONEncoder().encode(summary) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(summary.procedureId, summary.weekNumber))
    }

    private func cacheKey(_ procedureId: String, _ weekNumber: Int) -> String {
        "\(cachePrefix)\(procedureId)_wk\(weekNumber)"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension WeeklyCheckIn {
    init(
        id: UUID,
        procedureId: String,
        procedureName: String,
        weekNumber: Int,
        scheduledDate: Date,
        completedEntryId: UUID?,
        isCompleted: Bool,
        satisfactionRating: Int?,
        generatedAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.procedureId = procedureId
        self.procedureName = procedureName
        self.weekNumber = weekNumber
        self.scheduledDate = scheduledDate
        self.completedEntryId = completedEntryId
        self.isCompleted = isCompleted
        self.satisfactionRating = satisfactionRating
        self.generatedAt = generatedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
