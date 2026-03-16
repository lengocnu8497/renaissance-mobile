//
//  JournalViewModel.swift
//  Renaissance Mobile
//

import Foundation
import Observation
import Supabase

@Observable
class JournalViewModel {

    // MARK: - State

    var entries: [JournalEntry] = []
    var isLoading = false
    var error: String?

    /// Procedure filter; nil = show all procedures
    var selectedProcedureId: String?

    /// Grouped entries for the timeline: [(procedureName, [entries sorted by dayNumber])]
    var groupedByProcedure: [(key: String, entries: [JournalEntry])] {
        let filtered = selectedProcedureId == nil
            ? entries
            : entries.filter { $0.procedureId == selectedProcedureId }

        let dict = Dictionary(grouping: filtered, by: \.procedureName)
        return dict
            .map { (key: $0.key, entries: $0.value.sorted { $0.dayNumber < $1.dayNumber }) }
            .sorted { $0.key < $1.key }
    }

    /// All unique procedures that have journal entries
    var proceduresWithEntries: [(id: String, name: String)] {
        var seen = Set<String>()
        return entries.compactMap { entry -> (String, String)? in
            guard !seen.contains(entry.procedureId) else { return nil }
            seen.insert(entry.procedureId)
            return (entry.procedureId, entry.procedureName)
        }
    }

    // MARK: - Add Entry Sheet State

    var showAddEntry = false
    var showConsentBanner = false
    /// Pre-filled procedure name when adding from inside a specific journal
    var pendingProcedureName: String?
    var hasGivenConsent: Bool {
        get { UserDefaults.standard.bool(forKey: "journal_photo_consent") }
        set { UserDefaults.standard.set(newValue, forKey: "journal_photo_consent") }
    }

    // MARK: - Insights State

    /// Cross-entry AI insights, keyed by procedureId
    var insights: [String: RecoveryInsights] = [:]

    /// ProcedureIds currently generating insights in the background
    var insightsGenerating: Set<String> = []

    // MARK: - Services

    private let journalService: any JournalServiceProtocol
    private let insightsService: any RecoveryInsightsServiceProtocol

    init(
        journalService: any JournalServiceProtocol = JournalService(),
        insightsService: any RecoveryInsightsServiceProtocol = RecoveryInsightsService()
    ) {
        self.journalService = journalService
        self.insightsService = insightsService
    }

    // MARK: - Load

    @MainActor
    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            entries = try await journalService.fetchEntries(for: selectedProcedureId)
            loadCachedInsights()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Restores insights from local cache for all procedures that have >= 2 entries.
    /// Cache is keyed by procedureId + entryCount — if entries changed, cache is stale.
    private func loadCachedInsights() {
        for group in groupedByProcedure where group.entries.count >= 2 {
            guard let procedureId = group.entries.first?.procedureId else { continue }
            if let cached = insightsService.fetchCached(
                procedureId: procedureId,
                currentEntryCount: group.entries.count
            ) {
                insights[procedureId] = cached
            }
        }
    }

    // MARK: - Create

    /// Returns `true` on success so the caller (the sheet view) can dismiss itself
    /// before the fire-and-forget analysis/insights work begins — preventing
    /// EXC_BAD_ACCESS from writing to deallocated `@State` storage after dismiss.
    /// Note: do NOT set isLoading here; AddJournalEntryView owns its own isSaving
    /// state, and touching isLoading triggers @Observable re-renders of the parent
    /// view while the sheet's Task is still in-flight, which can corrupt @State.
    @MainActor
    func addEntry(
        procedureId: String,
        procedureName: String,
        dayNumber: Int,
        entryDate: Date,
        notes: String?,
        photoData: Data?
    ) async -> Bool {
        do {
            let entry = try await journalService.createEntry(
                procedureId: procedureId,
                procedureName: procedureName,
                dayNumber: dayNumber,
                entryDate: entryDate,
                notes: notes,
                photoData: photoData
            )
            entries.insert(entry, at: 0)
            if !hasEverLoggedEntry { hasEverLoggedEntry = true }

            // Fire-and-forget: refresh insights after the sheet is gone.
            let capturedId = procedureId
            let capturedName = procedureName
            Task { @MainActor [weak self] in
                guard let self else { return }
                let count = self.entries.filter { $0.procedureId == capturedId }.count
                if count >= 2 {
                    await self.refreshInsights(for: capturedId, procedureName: capturedName)
                }
            }

            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Delete

    @MainActor
    func deleteEntry(_ entry: JournalEntry) async {
        do {
            try await journalService.deleteEntry(id: entry.id)
            entries.removeAll { $0.id == entry.id }
            // Clear insights for this procedure since entry count changed
            insights.removeValue(forKey: entry.procedureId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func deleteProcedureGroup(procedureId: String) async {
        let groupEntries = entries.filter { $0.procedureId == procedureId }
        for entry in groupEntries {
            do {
                try await journalService.deleteEntry(id: entry.id)
            } catch {
                self.error = error.localizedDescription
                return
            }
        }
        entries.removeAll { $0.procedureId == procedureId }
        insights.removeValue(forKey: procedureId)
    }

    // MARK: - Cross-Entry Insights

    /// Generates cross-entry insights for a procedure and stores the result.
    /// Safe to call from background tasks — updates @Observable state on MainActor.
    @MainActor
    func refreshInsights(for procedureId: String, procedureName: String) async {
        let procedureEntries = entries.filter { $0.procedureId == procedureId }
        guard procedureEntries.count >= 2 else { return }
        guard !insightsGenerating.contains(procedureId) else { return }

        insightsGenerating.insert(procedureId)
        defer { insightsGenerating.remove(procedureId) }

        do {
            let result = try await insightsService.generateInsights(
                entries: procedureEntries,
                procedureName: procedureName,
                procedureId: procedureId
            )
            insights[procedureId] = result
        } catch {
            // Non-fatal: insights are supplementary, not blocking
            print("RecoveryInsights generation failed for \(procedureName): \(error)")
        }
    }

    // MARK: - Empty State

    var hasEverLoggedEntry: Bool {
        get { UserDefaults.standard.bool(forKey: "journal_has_ever_logged") }
        set { UserDefaults.standard.set(newValue, forKey: "journal_has_ever_logged") }
    }

    // MARK: - Derived Display Data

    /// Consecutive days with at least one entry, ending today or yesterday.
    var streak: Int {
        guard !entries.isEmpty else { return 0 }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let uniqueDates = Set(entries.map(\.entryDate))

        var startDate = Date()
        if !uniqueDates.contains(formatter.string(from: startDate)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: startDate),
                  uniqueDates.contains(formatter.string(from: yesterday)) else { return 0 }
            startDate = yesterday
        }

        var count = 0
        var checkDate = startDate
        while uniqueDates.contains(formatter.string(from: checkDate)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return count
    }

    /// Data for the recovery hero card: most recently logged procedure.
    var heroData: (procedureName: String, dayNumber: Int, progress: Double)? {
        guard let mostRecent = entries.max(by: { $0.entryDateAsDate < $1.entryDateAsDate }) else { return nil }
        let progress = min(Double(mostRecent.dayNumber) / 30.0, 1.0)
        return (mostRecent.procedureName, mostRecent.dayNumber, progress)
    }

    /// The 7 days of the current calendar week (locale-respecting first weekday).
    var currentWeekDates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let firstWeekday = calendar.firstWeekday
        let daysFromStart = (weekday - firstWeekday + 7) % 7
        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysFromStart, to: today) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    /// AI insights for the procedure with the most entries.
    var primaryInsights: RecoveryInsights? {
        guard let primaryId = groupedByProcedure.max(by: { $0.entries.count < $1.entries.count })?.entries.first?.procedureId else { return nil }
        return insights[primaryId]
    }

    var isPrimaryGenerating: Bool {
        guard let primaryId = groupedByProcedure.max(by: { $0.entries.count < $1.entries.count })?.entries.first?.procedureId else { return false }
        return insightsGenerating.contains(primaryId)
    }

    // MARK: - Consent

    func requestConsent() {
        if !hasGivenConsent { showConsentBanner = true }
    }

    func grantConsent() {
        hasGivenConsent = true
        showConsentBanner = false
        showAddEntry = true
    }

    func denyConsent() {
        showConsentBanner = false
    }

    func tapAddEntry(for procedureName: String? = nil) {
        pendingProcedureName = procedureName
        if hasGivenConsent {
            showAddEntry = true
        } else {
            showConsentBanner = true
        }
    }
}
