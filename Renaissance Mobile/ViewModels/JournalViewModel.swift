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

    // MARK: - Analysis State

    var analyzingEntryId: UUID?
    var analysisError: String?

    // MARK: - Insights State

    /// Cross-entry AI insights, keyed by procedureId
    var insights: [String: RecoveryInsights] = [:]

    /// ProcedureIds currently generating insights in the background
    var insightsGenerating: Set<String> = []

    // MARK: - Services

    private let journalService: JournalService
    private let analysisService: SkinAnalysisService
    private let insightsService: RecoveryInsightsService

    init(
        journalService: JournalService = JournalService(),
        analysisService: SkinAnalysisService = SkinAnalysisService(),
        insightsService: RecoveryInsightsService = RecoveryInsightsService()
    ) {
        self.journalService = journalService
        self.analysisService = analysisService
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

    @MainActor
    func addEntry(
        procedureId: String,
        procedureName: String,
        dayNumber: Int,
        entryDate: Date,
        notes: String?,
        photoData: Data?
    ) async {
        isLoading = true
        defer { isLoading = false }

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
            showAddEntry = false
            pendingProcedureName = nil

            // Auto-analyze photo if attached
            if photoData != nil {
                await analyzeEntry(entry)
            }

            // Regenerate cross-entry insights in background if procedure has enough entries
            let procedureEntries = entries.filter { $0.procedureId == procedureId }
            if procedureEntries.count >= 2 {
                Task {
                    await refreshInsights(for: procedureId, procedureName: procedureName)
                }
            }
        } catch {
            self.error = error.localizedDescription
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

    // MARK: - Analyze (per-entry photo)

    @MainActor
    func analyzeEntry(_ entry: JournalEntry) async {
        guard let photoUrl = entry.photoUrl else { return }
        analyzingEntryId = entry.id
        analysisError = nil
        defer { analyzingEntryId = nil }

        do {
            let result = try await analysisService.analyze(
                photoUrl: photoUrl,
                procedureName: entry.procedureName,
                dayNumber: entry.dayNumber
            )

            let update = JournalAnalysisUpdate(
                swellingIndex: result.swellingIndex,
                bruisingIndex: result.bruisingIndex,
                rednessIndex: result.rednessIndex,
                overallScore: result.overallScore,
                summary: result.summary,
                zones: result.zones.map { ZoneAnalysis(zone: $0.zone, score: $0.score, notes: $0.notes) }
            )

            let updated = try await journalService.updateAnalysis(id: entry.id, analysis: update)
            if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[idx] = updated
            }
        } catch {
            let message = "Analysis unavailable: \(error.localizedDescription)"
            analysisError = message
            self.error = message
        }
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
