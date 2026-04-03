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
        photoData: Data?,
        painLevel: Int? = nil,
        bruisingLevel: Int? = nil,
        swellingLevel: Int? = nil,
        rednessLevel: Int? = nil
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

// MARK: - RecoveryInsights Test Fixture

extension RecoveryInsights {
    static func stub(
        procedureId: String = "rhinoplasty",
        procedureName: String = "Rhinoplasty",
        trend: TrendDirection = .improving,
        flags: [InsightFlag] = [],
        encouragements: [String] = [],
        nextSteps: String? = nil
    ) -> RecoveryInsights {
        RecoveryInsights(
            summary: "Test summary",
            trend: trend,
            flags: flags,
            encouragements: encouragements,
            nextSteps: nextSteps,
            procedureId: procedureId,
            procedureName: procedureName,
            generatedAt: Date(),
            entryCount: 3
        )
    }
}

// MARK: - TreatmentReminder Test Fixture

extension TreatmentReminder {
    static func stub(
        procedureName: String = "Rhinoplasty",
        daysFromNow: Int = 7,
        kind: TreatmentReminderKind = .followUp
    ) -> TreatmentReminder {
        TreatmentReminder(
            procedureName: procedureName,
            procedureDate: Date(),
            reminderDate: Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date(),
            label: "1-week check-up",
            kind: kind
        )
    }
}

// MARK: - JournalEntry Test Fixture

extension JournalEntry {
    static func stub(
        procedureId: String = "rhinoplasty",
        procedureName: String = "Rhinoplasty",
        dayNumber: Int = 1,
        entryDate: Date = Date(),
        notes: String? = nil,
        painLevel: Double? = nil,
        bruisingLevel: Double? = nil,
        swellingLevel: Double? = nil,
        rednessLevel: Double? = nil
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
            painLevel: painLevel,
            bruisingLevel: bruisingLevel,
            swellingLevel: swellingLevel,
            rednessLevel: rednessLevel,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
