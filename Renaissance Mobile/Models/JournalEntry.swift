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

