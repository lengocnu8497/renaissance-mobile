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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        procedureId = try container.decode(String.self, forKey: .procedureId)
        procedureName = try container.decode(String.self, forKey: .procedureName)
        weekNumber = try container.decode(Int.self, forKey: .weekNumber)
        scheduledDate = try Self.decodeFlexibleDate(from: container, forKey: .scheduledDate)
        completedEntryId = try container.decodeIfPresent(UUID.self, forKey: .completedEntryId)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        satisfactionRating = try container.decodeIfPresent(Int.self, forKey: .satisfactionRating)
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
