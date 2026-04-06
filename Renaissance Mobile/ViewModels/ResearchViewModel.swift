//
//  ResearchViewModel.swift
//  Renaissance Mobile
//

import Foundation
import Supabase

struct SavedProcedureCardModel: Identifiable {
    let id: UUID
    let savedId: UUID
    let procedure: Procedure
    let questionCount: Int
    let hasNotes: Bool
    let linkedSessionCount: Int
}

@MainActor
@Observable
class ResearchViewModel {
    var savedProcedures: [SavedProcedure] = []
    var procedures: [Procedure] = []     // Full procedure objects for saved ones
    var isLoading = false
    var errorMessage: String?

    private let savedService = SavedProcedureService(supabase: supabase)
    private let chatDatabase = ChatDatabaseService(supabase: supabase)

    var shortlistCards: [SavedProcedureCardModel] {
        savedProcedures.compactMap { saved in
            guard let procedure = procedure(for: saved) else { return nil }
            return SavedProcedureCardModel(
                id: procedure.id,
                savedId: saved.id,
                procedure: procedure,
                questionCount: saved.questions.count,
                hasNotes: !(saved.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
                linkedSessionCount: saved.conversationIds.count
            )
        }
    }

    var exploreSuggestions: [String] {
        var suggestions: [String] = []

        if let firstSaved = shortlistCards.first {
            suggestions.append("Questions for \(firstSaved.procedure.name)")
            if !firstSaved.procedure.recoveryDurationLabel.isEmpty {
                suggestions.append("\(firstSaved.procedure.name) recovery")
            }
        }

        let related = procedures
            .filter { procedure in
                !savedProcedures.contains(where: { $0.procedureId == procedure.id })
            }
            .prefix(2)
            .map(\.name)

        suggestions.append(contentsOf: related)

        let defaults = [
            "Consultation prep",
            "Procedure cost range",
            "Recovery timeline"
        ]

        for item in defaults where !suggestions.contains(item) {
            suggestions.append(item)
        }

        return Array(suggestions.prefix(4))
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            savedProcedures = try await savedService.fetchSaved()
            // Fetch full procedure details for each saved ID
            if !savedProcedures.isEmpty {
                let ids = savedProcedures.map { $0.procedureId.uuidString.lowercased() }
                procedures = try await supabase.database
                    .from("procedures")
                    .select()
                    .in("id", values: ids)
                    .execute()
                    .value
            }
        } catch {
            print("ResearchViewModel load error: \(error)")
            errorMessage = "Unable to load your research list"
        }
    }

    // MARK: - Toggle Save

    func toggleSave(_ procedure: Procedure) async {
        if let existing = savedProcedures.first(where: { $0.procedureId == procedure.id }) {
            // Unsave
            savedProcedures.removeAll { $0.id == existing.id }
            procedures.removeAll { $0.id == procedure.id }
            do {
                try await savedService.unsave(procedureId: procedure.id)
            } catch {
                // Revert on failure
                savedProcedures.append(existing)
                if !procedures.contains(where: { $0.id == procedure.id }) {
                    procedures.append(procedure)
                }
                print("Failed to unsave: \(error)")
            }
        } else {
            // Save
            do {
                let saved = try await savedService.save(procedureId: procedure.id)
                savedProcedures.insert(saved, at: 0)
                if !procedures.contains(where: { $0.id == procedure.id }) {
                    procedures.insert(procedure, at: 0)
                }
            } catch {
                print("Failed to save: \(error)")
            }
        }
    }

    func isSaved(_ procedureId: UUID) -> Bool {
        savedProcedures.contains { $0.procedureId == procedureId }
    }

    func savedEntry(for procedureId: UUID) -> SavedProcedure? {
        savedProcedures.first { $0.procedureId == procedureId }
    }

    func procedure(for savedProcedure: SavedProcedure) -> Procedure? {
        procedures.first { $0.id == savedProcedure.procedureId }
    }

    // MARK: - Questions

    func addQuestion(_ question: String, to savedId: UUID) async {
        guard let idx = savedProcedures.firstIndex(where: { $0.id == savedId }) else { return }
        let current = savedProcedures[idx].questions
        do {
            let updated = try await savedService.addQuestion(question, to: savedId, currentQuestions: current)
            savedProcedures[idx] = updated
        } catch {
            print("Failed to add question: \(error)")
        }
    }

    func removeQuestion(at questionIndex: Int, from savedId: UUID) async {
        guard let idx = savedProcedures.firstIndex(where: { $0.id == savedId }) else { return }
        let current = savedProcedures[idx].questions
        do {
            let updated = try await savedService.removeQuestion(at: questionIndex, from: savedId, currentQuestions: current)
            savedProcedures[idx] = updated
        } catch {
            print("Failed to remove question: \(error)")
        }
    }

    // MARK: - Notes

    func updateNotes(_ notes: String, for savedId: UUID) async -> Bool {
        guard let idx = savedProcedures.firstIndex(where: { $0.id == savedId }) else { return false }
        savedProcedures[idx].notes = notes
        do {
            try await savedService.updateNotes(notes, for: savedId)
            return true
        } catch {
            print("Failed to update notes: \(error)")
            return false
        }
    }

    // MARK: - Research Sessions

    /// Refreshes a single saved procedure from DB so conversationIds stays current.
    func refresh(savedId: UUID) async {
        do {
            let fresh = try await savedService.fetchById(savedId)
            if let idx = savedProcedures.firstIndex(where: { $0.id == savedId }) {
                savedProcedures[idx] = fresh
            }
        } catch {
            print("ResearchViewModel refresh error: \(error)")
        }
    }

    /// Fetches ChatConversation objects for the given IDs (linked research sessions).
    func fetchConversations(for conversationIds: [UUID]) async -> [ChatConversation] {
        guard !conversationIds.isEmpty else { return [] }
        return (try? await chatDatabase.getConversations(ids: conversationIds)) ?? []
    }

    // MARK: - Export

    func exportText(for savedId: UUID) -> String {
        guard let saved = savedProcedures.first(where: { $0.id == savedId }),
              let proc = procedure(for: saved) else { return "" }

        var lines: [String] = []
        lines.append("Consultation Prep: \(proc.name)")
        lines.append(String(repeating: "—", count: 40))

        if !saved.questions.isEmpty {
            lines.append("\nMy Questions:")
            saved.questions.enumerated().forEach { i, q in
                lines.append("  \(i + 1). \(q)")
            }
        }

        if let notes = saved.notes, !notes.isEmpty {
            lines.append("\nNotes:")
            lines.append(notes)
        }

        lines.append("\n\nPrepared with Rena Aesthetic Lab")
        return lines.joined(separator: "\n")
    }
}
