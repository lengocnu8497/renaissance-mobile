//
//  JournalViewModelTests.swift
//  Renaissance MobileTests
//
//  Tests for JournalViewModel.addEntry — specifically the no-photo, text-only save path
//  that previously triggered EXC_BAD_ACCESS (code=2) due to defer { isLoading = false }
//  running before the caller's Task resumed, causing @Observable re-renders of
//  PhotoJournalView while the sheet's Task was still in-flight.
//

import XCTest
@testable import Renaissance_Mobile

final class JournalViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeVM(service: MockJournalService = MockJournalService())
        -> (vm: JournalViewModel, service: MockJournalService)
    {
        let vm = JournalViewModel(
            journalService: service,
            insightsService: MockRecoveryInsightsService()
        )
        return (vm, service)
    }

    // MARK: - addEntry: no photo, text only

    /// Baseline: save succeeds and returns true.
    func testAddEntryNoPhoto_returnsTrue() async throws {
        let (vm, _) = makeVM()

        let result = await vm.addEntry(
            procedureId: "rhinoplasty",
            procedureName: "Rhinoplasty",
            dayNumber: 1,
            entryDate: Date(),
            notes: "Feeling okay",
            photoData: nil
        )

        XCTAssertTrue(result)
    }

    /// Entry is inserted into vm.entries immediately after addEntry returns.
    func testAddEntryNoPhoto_insertsEntryIntoVM() async throws {
        let (vm, _) = makeVM()

        _ = await vm.addEntry(
            procedureId: "rhinoplasty",
            procedureName: "Rhinoplasty",
            dayNumber: 1,
            entryDate: Date(),
            notes: "Feeling okay",
            photoData: nil
        )

        XCTAssertEqual(vm.entries.count, 1)
        XCTAssertEqual(vm.entries.first?.procedureName, "Rhinoplasty")
        XCTAssertEqual(vm.entries.first?.notes, "Feeling okay")
    }

    /// No error is produced on a successful save.
    func testAddEntryNoPhoto_doesNotSetError() async throws {
        let (vm, _) = makeVM()

        _ = await vm.addEntry(
            procedureId: "rhinoplasty",
            procedureName: "Rhinoplasty",
            dayNumber: 1,
            entryDate: Date(),
            notes: "Feeling okay",
            photoData: nil
        )

        XCTAssertNil(vm.error)
    }

    /// REGRESSION TEST for EXC_BAD_ACCESS fix:
    /// addEntry must NOT set isLoading = true at any point during the call.
    ///
    /// When the bug was present, addEntry contained:
    ///   isLoading = true
    ///   defer { isLoading = false }
    /// The defer fired BEFORE the return value reached AddJournalEntryView's Task,
    /// triggering @Observable re-renders of PhotoJournalView mid-await,
    /// which could corrupt @State storage → EXC_BAD_ACCESS (code=2).
    ///
    /// The fix: removed isLoading manipulation from addEntry entirely.
    /// This test fails if that defer is ever re-introduced.
    func testAddEntryNoPhoto_doesNotMutateIsLoading() async throws {
        let service = MockJournalService()
        let (vm, _) = makeVM(service: service)

        // Capture vm.isLoading at the moment createEntry is called by the service.
        service.isLoadingProvider = { [weak vm] in vm?.isLoading ?? false }

        XCTAssertFalse(vm.isLoading, "isLoading should start false")

        _ = await vm.addEntry(
            procedureId: "rhinoplasty",
            procedureName: "Rhinoplasty",
            dayNumber: 1,
            entryDate: Date(),
            notes: "Just text, no photo",
            photoData: nil
        )

        XCTAssertFalse(vm.isLoading, "isLoading must remain false after addEntry")

        // Key regression guard: isLoading must have been false DURING createEntry.
        // Re-introducing `isLoading = true` at the top of addEntry breaks this.
        XCTAssertEqual(
            service.isLoadingSnapshotDuringCreate, false,
            "isLoading must not be true during createEntry — regression: defer { isLoading = false } was removed from addEntry to fix EXC_BAD_ACCESS"
        )
    }

    /// createEntry is called exactly once per addEntry invocation.
    func testAddEntryNoPhoto_callsCreateEntryOnce() async throws {
        let service = MockJournalService()
        let (vm, _) = makeVM(service: service)

        _ = await vm.addEntry(
            procedureId: "rhinoplasty",
            procedureName: "Rhinoplasty",
            dayNumber: 1,
            entryDate: Date(),
            notes: "Test",
            photoData: nil
        )

        XCTAssertEqual(service.createCallCount, 1)
    }

    /// When the service throws, addEntry returns false and sets vm.error.
    func testAddEntryNoPhoto_whenServiceThrows_returnsFalse() async throws {
        let service = MockJournalService()
        service.createError = NSError(
            domain: "TestError",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "Simulated network error"]
        )
        let (vm, _) = makeVM(service: service)

        let result = await vm.addEntry(
            procedureId: "rhinoplasty",
            procedureName: "Rhinoplasty",
            dayNumber: 1,
            entryDate: Date(),
            notes: "Test",
            photoData: nil
        )

        XCTAssertFalse(result)
        XCTAssertNotNil(vm.error)
        XCTAssertTrue(vm.entries.isEmpty)
    }

    /// isLoading stays false even when the service throws (no defer cleanup needed).
    func testAddEntryNoPhoto_isLoadingFalseOnFailure() async throws {
        let service = MockJournalService()
        service.createError = NSError(domain: "TestError", code: 1, userInfo: nil)
        let (vm, _) = makeVM(service: service)

        _ = await vm.addEntry(
            procedureId: "rhinoplasty",
            procedureName: "Rhinoplasty",
            dayNumber: 1,
            entryDate: Date(),
            notes: "Test",
            photoData: nil
        )

        XCTAssertFalse(vm.isLoading)
    }
}
