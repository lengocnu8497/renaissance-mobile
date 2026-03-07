//
//  JournalService.swift
//  Renaissance Mobile
//

import Foundation
import Supabase

private let _defaultSupabase: SupabaseClient = supabase

class JournalService {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient = _defaultSupabase) {
        self.supabase = supabase
    }

    // MARK: - Fetch

    func fetchEntries(for procedureId: String? = nil) async throws -> [JournalEntry] {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw JournalError.notAuthenticated
        }

        var query = supabase.database
            .from("journal_entries")
            .select()
            .eq("user_id", value: userId.uuidString)

        if let procedureId {
            query = query.eq("procedure_id", value: procedureId)
        }

        let entries: [JournalEntry] = try await query
            .order("entry_date", ascending: false)
            .execute()
            .value

        return entries
    }

    func fetchEntry(id: UUID) async throws -> JournalEntry {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw JournalError.notAuthenticated
        }

        let entry: JournalEntry = try await supabase.database
            .from("journal_entries")
            .select()
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .single()
            .execute()
            .value

        return entry
    }

    // MARK: - Create

    func createEntry(
        procedureId: String,
        procedureName: String,
        dayNumber: Int,
        entryDate: Date = Date(),
        notes: String?,
        photoData: Data?
    ) async throws -> JournalEntry {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw JournalError.notAuthenticated
        }

        let entryId = UUID()
        var photoPath: String?
        var photoUrl: String?

        // Upload photo first if provided
        if let data = photoData {
            (photoPath, photoUrl) = try await uploadPhoto(data, entryId: entryId, userId: userId)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let payload = JournalEntryInsert(
            userId: userId,
            procedureId: procedureId,
            procedureName: procedureName,
            dayNumber: dayNumber,
            entryDate: formatter.string(from: entryDate),
            notes: notes,
            photoPath: photoPath,
            photoUrl: photoUrl
        )

        let entry: JournalEntry = try await supabase.database
            .from("journal_entries")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        return entry
    }

    // MARK: - Update

    func updateNotes(id: UUID, notes: String) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw JournalError.notAuthenticated
        }

        try await supabase.database
            .from("journal_entries")
            .update(["notes": notes])
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func updateAnalysis(id: UUID, analysis: JournalAnalysisUpdate) async throws -> JournalEntry {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw JournalError.notAuthenticated
        }

        let entry: JournalEntry = try await supabase.database
            .from("journal_entries")
            .update(analysis)
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value

        return entry
    }

    // MARK: - Delete

    func deleteEntry(id: UUID) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw JournalError.notAuthenticated
        }

        // Remove photo from storage if present
        if let entry = try? await fetchEntry(id: id), let path = entry.photoPath {
            try? await supabase.storage.from("journals").remove(paths: [path])
        }

        try await supabase.database
            .from("journal_entries")
            .delete()
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Photo Upload

    /// Uploads a journal photo and returns (storagePath, signedURL).
    func uploadPhoto(_ data: Data, entryId: UUID, userId: UUID) async throws -> (String, String) {
        let ext = imageExtension(from: data)
        let path = "\(userId.uuidString.lowercased())/\(entryId.uuidString).\(ext)"

        try await supabase.storage
            .from("journals")
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: "image/\(ext)", upsert: true)
            )

        let signedURL = try await supabase.storage
            .from("journals")
            .createSignedURL(path: path, expiresIn: 31_536_000) // 1 year

        return (path, signedURL.absoluteString)
    }

    // MARK: - Helpers

    private func imageExtension(from data: Data) -> String {
        guard data.count > 12 else { return "jpg" }
        if data[0] == 0x89 && data[1] == 0x50 { return "png" }
        if data[0] == 0xFF && data[1] == 0xD8 { return "jpg" }
        if data[8] == 0x57 && data[9] == 0x45 { return "webp" }
        return "jpg"
    }
}

// MARK: - Errors

enum JournalError: LocalizedError {
    case notAuthenticated
    case entryNotFound
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "User is not authenticated"
        case .entryNotFound:    return "Journal entry not found"
        case .uploadFailed:     return "Failed to upload photo"
        }
    }
}
