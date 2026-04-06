//
//  SavedProcedureService.swift
//  Renaissance Mobile
//

import Foundation
import Supabase

struct SavedProcedureService {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    func fetchSaved() async throws -> [SavedProcedure] {
        try await supabase.database
            .from("saved_procedures")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func save(procedureId: UUID) async throws -> SavedProcedure {
        guard let userId = supabase.auth.currentUser?.id else {
            throw NSError(domain: "SavedProcedureService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        struct SavePayload: Encodable {
            let user_id: String
            let procedure_id: String
            let questions: [String]
            let conversation_ids: [String]
        }

        let body = SavePayload(
            user_id: userId.uuidString.lowercased(),
            procedure_id: procedureId.uuidString.lowercased(),
            questions: [],
            conversation_ids: []
        )
        return try await supabase.database
            .from("saved_procedures")
            .insert(body)
            .select()
            .single()
            .execute()
            .value
    }

    func unsave(procedureId: UUID) async throws {
        guard let userId = supabase.auth.currentUser?.id else { return }
        try await supabase.database
            .from("saved_procedures")
            .delete()
            .eq("user_id", value: userId.uuidString.lowercased())
            .eq("procedure_id", value: procedureId.uuidString.lowercased())
            .execute()
    }

    func addQuestion(_ question: String, to savedId: UUID, currentQuestions: [String]) async throws -> SavedProcedure {
        struct QuestionsUpdate: Encodable {
            let questions: [String]
            let updated_at: String
        }
        let updated = currentQuestions + [question]
        return try await supabase.database
            .from("saved_procedures")
            .update(QuestionsUpdate(questions: updated, updated_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: savedId.uuidString.lowercased())
            .select()
            .single()
            .execute()
            .value
    }

    func updateNotes(_ notes: String, for savedId: UUID) async throws {
        try await supabase.database
            .from("saved_procedures")
            .update(["notes": notes, "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: savedId.uuidString.lowercased())
            .execute()
    }

    func removeQuestion(at index: Int, from savedId: UUID, currentQuestions: [String]) async throws -> SavedProcedure {
        struct QuestionsUpdate: Encodable {
            let questions: [String]
            let updated_at: String
        }
        var updated = currentQuestions
        guard index < updated.count else { return try await fetchById(savedId) }
        updated.remove(at: index)
        return try await supabase.database
            .from("saved_procedures")
            .update(QuestionsUpdate(questions: updated, updated_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: savedId.uuidString.lowercased())
            .select()
            .single()
            .execute()
            .value
    }

    func fetchById(_ id: UUID) async throws -> SavedProcedure {
        try await supabase.database
            .from("saved_procedures")
            .select()
            .eq("id", value: id.uuidString.lowercased())
            .single()
            .execute()
            .value
    }

    /// Appends a conversationId to a saved procedure's conversation_ids array.
    /// No-ops if the ID is already linked.
    func linkConversation(_ conversationId: UUID, to savedId: UUID) async throws {
        let current = try await fetchById(savedId)
        guard !current.conversationIds.contains(conversationId) else { return }
        let updated = current.conversationIds + [conversationId]
        struct ConversationIdsUpdate: Encodable {
            let conversation_ids: [String]
            let updated_at: String
        }
        try await supabase.database
            .from("saved_procedures")
            .update(ConversationIdsUpdate(
                conversation_ids: updated.map { $0.uuidString.lowercased() },
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: savedId.uuidString.lowercased())
            .execute()
    }
}
