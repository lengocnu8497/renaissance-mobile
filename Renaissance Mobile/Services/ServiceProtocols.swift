//
//  ServiceProtocols.swift
//  Renaissance Mobile
//
//  Protocols abstracting each service for testability.
//

import Foundation

// MARK: - Journal

protocol JournalServiceProtocol {
    func fetchEntries(for procedureId: String?) async throws -> [JournalEntry]
    func createEntry(
        procedureId: String,
        procedureName: String,
        dayNumber: Int,
        entryDate: Date,
        notes: String?,
        photoData: Data?,
        bruisingLevel: Int?,
        swellingLevel: Int?,
        rednessLevel: Int?
    ) async throws -> JournalEntry
    func deleteEntry(id: UUID) async throws
}

// MARK: - Recovery Insights

protocol RecoveryInsightsServiceProtocol {
    func generateInsights(
        entries: [JournalEntry],
        procedureName: String,
        procedureId: String
    ) async throws -> RecoveryInsights
    func fetchCached(procedureId: String, currentEntryCount: Int) -> RecoveryInsights?
}
