//
//  JournalEntry.swift
//  Renaissance Mobile
//

import Foundation

// MARK: - Journal Entry Model

struct JournalEntry: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let procedureId: String
    let procedureName: String
    let dayNumber: Int          // 0 = day of procedure
    let entryDate: String       // "YYYY-MM-DD" — Supabase date columns return plain strings
    var notes: String?
    var photoPath: String?      // Supabase Storage path
    var photoUrl: String?       // cached URL

    // Gemini Vision analysis (nil if not yet analyzed)
    var analysisJson: [String: AnyCodableValue]?
    var swellingIndex: Double?
    var bruisingIndex: Double?
    var rednessIndex: Double?
    var overallScore: Double?
    var summary: String?
    var zones: [ZoneAnalysis]?

    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, notes, summary, zones
        case userId         = "user_id"
        case procedureId    = "procedure_id"
        case procedureName  = "procedure_name"
        case dayNumber      = "day_number"
        case entryDate      = "entry_date"
        case photoPath      = "photo_path"
        case photoUrl       = "photo_url"
        case analysisJson   = "analysis_json"
        case swellingIndex  = "swelling_index"
        case bruisingIndex  = "bruising_index"
        case rednessIndex   = "redness_index"
        case overallScore   = "overall_score"
        case createdAt      = "created_at"
        case updatedAt      = "updated_at"
    }

    // Convenience: human-readable day label
    var dayLabel: String {
        dayNumber == 0 ? "Day of Procedure" : "Day \(dayNumber)"
    }

    // Parsed date for display (entryDate is stored as "YYYY-MM-DD" string)
    var entryDateAsDate: Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: entryDate) ?? Date()
    }

    var hasAnalysis: Bool { overallScore != nil }
}

// MARK: - Zone Analysis

struct ZoneAnalysis: Codable, Identifiable {
    let zone: String
    let score: Double       // 0–10
    let notes: String?

    var id: String { zone }
}

// MARK: - AnyCodableValue (for analysis_json JSONB field)

enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil()                                  { self = .null }
        else if let v = try? container.decode(Bool.self)          { self = .bool(v) }
        else if let v = try? container.decode(Int.self)           { self = .int(v) }
        else if let v = try? container.decode(Double.self)        { self = .double(v) }
        else if let v = try? container.decode(String.self)        { self = .string(v) }
        else if let v = try? container.decode([AnyCodableValue].self) { self = .array(v) }
        else if let v = try? container.decode([String: AnyCodableValue].self) { self = .object(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:          try container.encodeNil()
        case .bool(let v):   try container.encode(v)
        case .int(let v):    try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .array(let v):  try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }
}

// MARK: - Insert Payload (no id/created_at — server generates them)

struct JournalEntryInsert: Encodable {
    let userId: UUID
    let procedureId: String
    let procedureName: String
    let dayNumber: Int
    let entryDate: String       // ISO date string "YYYY-MM-DD"
    var notes: String?
    var photoPath: String?
    var photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case notes
        case userId        = "user_id"
        case procedureId   = "procedure_id"
        case procedureName = "procedure_name"
        case dayNumber     = "day_number"
        case entryDate     = "entry_date"
        case photoPath     = "photo_path"
        case photoUrl      = "photo_url"
    }
}

// MARK: - Analysis Update Payload

struct JournalAnalysisUpdate: Encodable {
    let swellingIndex: Double?
    let bruisingIndex: Double?
    let rednessIndex: Double?
    let overallScore: Double?
    let summary: String?
    let zones: [ZoneAnalysis]?

    enum CodingKeys: String, CodingKey {
        case summary, zones
        case swellingIndex = "swelling_index"
        case bruisingIndex = "bruising_index"
        case rednessIndex  = "redness_index"
        case overallScore  = "overall_score"
    }
}
