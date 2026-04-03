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

    // Recovery metrics (0–10 scale stored as NUMERIC in DB)
    var painLevel: Double?      // maps to pain_index
    var bruisingLevel: Double?  // maps to bruising_index
    var swellingLevel: Double?  // maps to swelling_index
    var rednessLevel: Double?   // maps to redness_index

    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, notes
        case userId         = "user_id"
        case procedureId    = "procedure_id"
        case procedureName  = "procedure_name"
        case dayNumber      = "day_number"
        case entryDate      = "entry_date"
        case photoPath      = "photo_path"
        case photoUrl       = "photo_url"
        case painLevel      = "pain_index"
        case bruisingLevel  = "bruising_index"
        case swellingLevel  = "swelling_index"
        case rednessLevel   = "redness_index"
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

    // Integer accessors for UI display
    var painInt: Int { Int(painLevel ?? 0) }
    var bruisingInt: Int { Int(bruisingLevel ?? 0) }
    var swellingInt: Int { Int(swellingLevel ?? 0) }
    var rednessInt:  Int { Int(rednessLevel  ?? 0) }

    var hasRecoveryMetrics: Bool {
        painLevel != nil || bruisingLevel != nil || swellingLevel != nil || rednessLevel != nil
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
    var painLevel: Int?         // maps to pain_index
    var bruisingLevel: Int?     // maps to bruising_index
    var swellingLevel: Int?     // maps to swelling_index
    var rednessLevel: Int?      // maps to redness_index

    enum CodingKeys: String, CodingKey {
        case notes
        case userId        = "user_id"
        case procedureId   = "procedure_id"
        case procedureName = "procedure_name"
        case dayNumber     = "day_number"
        case entryDate     = "entry_date"
        case photoPath     = "photo_path"
        case photoUrl      = "photo_url"
        case painLevel     = "pain_index"
        case bruisingLevel = "bruising_index"
        case swellingLevel = "swelling_index"
        case rednessLevel  = "redness_index"
    }
}
