//
//  MockServices.swift
//  Renaissance MobileTests
//

import Foundation
@testable import Renaissance_Mobile

// MARK: - Mock Journal Service

final class MockJournalService: JournalServiceProtocol {
    var fetchResult: [JournalEntry] = []
    var createResult: JournalEntry?
    var createError: Error?
    var createCallCount = 0
    /// Called at the moment createEntry executes — lets tests snapshot VM state mid-call.
    var isLoadingProvider: (() -> Bool)?
    var isLoadingSnapshotDuringCreate: Bool?

    func fetchEntries(for procedureId: String? = nil) async throws -> [JournalEntry] {
        fetchResult
    }

    func createEntry(
        procedureId: String,
        procedureName: String,
        dayNumber: Int,
        entryDate: Date,
        notes: String?,
        photoData: Data?
    ) async throws -> JournalEntry {
        createCallCount += 1
        isLoadingSnapshotDuringCreate = isLoadingProvider?()
        if let error = createError { throw error }
        return createResult ?? .stub(
            procedureId: procedureId,
            procedureName: procedureName,
            dayNumber: dayNumber,
            entryDate: entryDate,
            notes: notes
        )
    }

    func deleteEntry(id: UUID) async throws {}
}

// MARK: - Mock Recovery Insights Service

final class MockRecoveryInsightsService: RecoveryInsightsServiceProtocol {
    func generateInsights(
        entries: [JournalEntry],
        procedureName: String,
        procedureId: String
    ) async throws -> RecoveryInsights {
        throw CancellationError()
    }

    func fetchCached(procedureId: String, currentEntryCount: Int) -> RecoveryInsights? {
        nil
    }
}

// MARK: - JournalEntry Test Fixture

extension JournalEntry {
    static func stub(
        procedureId: String = "rhinoplasty",
        procedureName: String = "Rhinoplasty",
        dayNumber: Int = 1,
        entryDate: Date = Date(),
        notes: String? = nil
    ) -> JournalEntry {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return JournalEntry(
            id: UUID(),
            userId: UUID(),
            procedureId: procedureId,
            procedureName: procedureName,
            dayNumber: dayNumber,
            entryDate: formatter.string(from: entryDate),
            notes: notes,
            photoPath: nil,
            photoUrl: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
