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
    var hasGivenConsent: Bool {
        get { UserDefaults.standard.bool(forKey: "journal_photo_consent") }
        set { UserDefaults.standard.set(newValue, forKey: "journal_photo_consent") }
    }

    // MARK: - Analysis State

    var analyzingEntryId: UUID?
    var analysisError: String?

    // MARK: - Services

    private let journalService: JournalService
    private let analysisService: SkinAnalysisService

    init(
        journalService: JournalService = JournalService(),
        analysisService: SkinAnalysisService = SkinAnalysisService()
    ) {
        self.journalService = journalService
        self.analysisService = analysisService
    }

    // MARK: - Load

    @MainActor
    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            entries = try await journalService.fetchEntries(for: selectedProcedureId)
        } catch {
            self.error = error.localizedDescription
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

            // Auto-analyze if photo was attached
            if photoData != nil {
                await analyzeEntry(entry)
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
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Analyze

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

    // MARK: - Consent

    func requestConsent() {
        if !hasGivenConsent {
            showConsentBanner = true
        }
    }

    func grantConsent() {
        hasGivenConsent = true
        showConsentBanner = false
        showAddEntry = true
    }

    func denyConsent() {
        showConsentBanner = false
    }

    func tapAddEntry() {
        if hasGivenConsent {
            showAddEntry = true
        } else {
            showConsentBanner = true
        }
    }
}
