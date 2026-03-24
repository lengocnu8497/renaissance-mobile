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
    /// Procedure ID bootstrapped from onboarding — used to show check-ins before the first journal entry exists
    var bootstrappedProcedureId: String?
    var hasGivenConsent: Bool {
        get { UserDefaults.standard.bool(forKey: "journal_photo_consent") }
        set { UserDefaults.standard.set(newValue, forKey: "journal_photo_consent") }
    }

    // MARK: - Insights State

    /// Cross-entry AI insights, keyed by procedureId
    var insights: [String: RecoveryInsights] = [:]

    /// ProcedureIds currently generating insights in the background
    var insightsGenerating: Set<String> = []

    /// Set to false for free-tier users to prevent edge function calls.
    /// Defaults to false — set to true only after subscription is confirmed,
    /// so the cache is never loaded before we know the user's tier.
    var insightsEnabled = false

    // MARK: - Weekly Summary State

    /// Weekly summaries keyed by "\(procedureId)-wk\(weekNumber)"
    var weeklySummaries: [String: WeeklySummary] = [:]

    /// Keys currently being generated
    var weeklySummaryGenerating: Set<String> = []

    // MARK: - Services

    private let journalService: any JournalServiceProtocol
    private let insightsService: any RecoveryInsightsServiceProtocol
    private let weeklySummaryService = WeeklySummaryService()

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
            // Cache is loaded separately in loadCachedInsights(), called only after
            // insightsEnabled is set to true by the subscription check.
            await bootstrapCheckInsIfNeeded()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Restores insights from local cache for all procedures that have >= 2 entries.
    /// Cache is keyed by procedureId + entryCount — if entries changed, cache is stale.
    /// Must be called only after insightsEnabled has been set (i.e. after subscription check).
    func loadCachedInsights() {
        guard insightsEnabled else { return }
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
    /// Note: do NOT set isLoading here; AddJournalEntryView owns its own isSaving
    /// state, and touching isLoading triggers @Observable re-renders of the parent
    /// view while the sheet's Task is still in-flight, which can corrupt @State.
    /// Insights are NOT triggered here — PhotoJournalView observes vm.entries.count
    /// and drives refreshInsights reactively after the sheet has fully dismissed.
    @MainActor
    func addEntry(
        procedureId: String,
        procedureName: String,
        dayNumber: Int,
        entryDate: Date,
        notes: String?,
        photoData: Data?,
        bruisingLevel: Int? = nil,
        swellingLevel: Int? = nil,
        rednessLevel: Int? = nil
    ) async -> Bool {
        do {
            let entry = try await journalService.createEntry(
                procedureId: procedureId,
                procedureName: procedureName,
                dayNumber: dayNumber,
                entryDate: entryDate,
                notes: notes,
                photoData: photoData,
                bruisingLevel: bruisingLevel,
                swellingLevel: swellingLevel,
                rednessLevel: rednessLevel
            )
            entries.insert(entry, at: 0)
            if !hasEverLoggedEntry { hasEverLoggedEntry = true }

            // Bootstrap weekly check-ins if this is the first entry for this procedure
            let isFirstEntry = entries.filter { $0.procedureId == entry.procedureId }.count == 1
            if isFirstEntry {
                let checkIns = WeeklyCheckInService.shared.generateCheckIns(
                    procedureId: entry.procedureId,
                    procedureName: entry.procedureName,
                    startDate: entry.entryDateAsDate
                )
                WeeklyCheckInService.shared.saveCheckIns(checkIns)
                Task {
                    await WeeklyCheckInService.shared.scheduleNotifications(
                        for: checkIns, procedureName: entry.procedureName
                    )
                }
            }
            // Auto-fulfill any pending check-in for this procedure
            if let pending = WeeklyCheckInService.shared.firstIncompleteCheckIn(for: entry.procedureId) {
                WeeklyCheckInService.shared.markCompleted(
                    weekNumber: pending.weekNumber,
                    procedureId: entry.procedureId,
                    entryId: entry.id
                )
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
        guard insightsEnabled else { return }
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

    /// Data for the recovery hero card: procedure with the most entries, day count live-calculated from today.
    var heroData: (procedureName: String, dayNumber: Int, progress: Double)? {
        // Use the procedure with the most entries as the "primary" procedure
        guard let primaryGroup = groupedByProcedure.max(by: { $0.entries.count < $1.entries.count }),
              let earliest = primaryGroup.entries.min(by: { $0.entryDateAsDate < $1.entryDateAsDate })
        else { return nil }

        let cal = Calendar.current
        let dayNumber = max(0, cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: earliest.entryDateAsDate),
            to: cal.startOfDay(for: Date())
        ).day ?? 0)

        let progress = min(Double(dayNumber) / 30.0, 1.0)
        return (earliest.procedureName, dayNumber, progress)
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

    // MARK: - Weekly Check-In

    /// Pending check-in for the primary procedure (most entries), if any.
    /// Falls back to bootstrappedProcedureId when no journal entries exist yet.
    var primaryPendingCheckIn: WeeklyCheckIn? {
        let primaryId = groupedByProcedure
            .max(by: { $0.entries.count < $1.entries.count })?
            .entries.first?.procedureId
            ?? bootstrappedProcedureId
        guard let primaryId else { return nil }
        return WeeklyCheckInService.shared.pendingCheckIn(for: primaryId)
    }

    /// All check-ins for a given procedure (for the progress strip).
    func checkIns(for procedureId: String) -> [WeeklyCheckIn] {
        WeeklyCheckInService.shared.loadCheckIns(for: procedureId)
    }

    /// Bootstrap check-ins for any procedure that has entries but no schedule yet.
    /// Call once after load() completes.
    @MainActor
    func bootstrapCheckInsIfNeeded() async {
        for group in groupedByProcedure {
            guard let earliest = group.entries.min(by: { $0.entryDateAsDate < $1.entryDateAsDate }),
                  WeeklyCheckInService.shared.loadCheckIns(for: earliest.procedureId).isEmpty
            else { continue }
            let checkIns = WeeklyCheckInService.shared.generateCheckIns(
                procedureId: earliest.procedureId,
                procedureName: group.key,
                startDate: earliest.entryDateAsDate
            )
            WeeklyCheckInService.shared.saveCheckIns(checkIns)
            await WeeklyCheckInService.shared.scheduleNotifications(
                for: checkIns, procedureName: group.key
            )
        }
    }

    // MARK: - Weekly Summary

    func weeklySummaryKey(_ procedureId: String, _ weekNumber: Int) -> String {
        "\(procedureId)-wk\(weekNumber)"
    }

    /// Restores cached weekly summaries for all completed check-ins.
    /// Call after insightsEnabled is confirmed true.
    func loadCachedWeeklySummaries() {
        guard insightsEnabled else { return }
        for group in groupedByProcedure {
            guard let procedureId = group.entries.first?.procedureId else { continue }
            let checkIns = WeeklyCheckInService.shared.loadCheckIns(for: procedureId)
            for checkIn in checkIns where checkIn.isCompleted {
                let key = weeklySummaryKey(procedureId, checkIn.weekNumber)
                if let cached = weeklySummaryService.fetchCached(
                    procedureId: procedureId, weekNumber: checkIn.weekNumber
                ) {
                    weeklySummaries[key] = cached
                }
            }
        }
    }

    /// Generates a weekly summary for the given procedure week.
    /// Non-fatal: errors are logged, not surfaced to the user.
    @MainActor
    func refreshWeeklySummary(for procedureId: String, procedureName: String, weekNumber: Int) async {
        guard insightsEnabled else { return }
        let key = weeklySummaryKey(procedureId, weekNumber)
        guard !weeklySummaryGenerating.contains(key) else { return }

        weeklySummaryGenerating.insert(key)
        defer { weeklySummaryGenerating.remove(key) }

        let procedureEntries = entries.filter { $0.procedureId == procedureId }
        guard !procedureEntries.isEmpty else { return }

        do {
            let summary = try await weeklySummaryService.generateSummary(
                procedureId: procedureId,
                procedureName: procedureName,
                weekNumber: weekNumber,
                entries: procedureEntries
            )
            weeklySummaries[key] = summary
        } catch {
            print("WeeklySummary generation failed wk\(weekNumber) \(procedureName): \(error)")
        }
    }

    // MARK: - Urgent Flag Reminder Check

    /// Pure function: returns `true` when `insights` contains at least one `.urgent` flag
    /// AND no active upcoming reminder exists for that procedure name.
    ///
    /// Keeping this `static` and accepting the reminders array as a parameter makes it
    /// trivially testable without any mock setup.
    static func urgentFlagNeedsReminder(
        insights: RecoveryInsights,
        upcomingReminders: [TreatmentReminder]
    ) -> Bool {
        guard insights.flags.contains(where: { $0.severity == .urgent }) else { return false }
        let name = insights.procedureName.lowercased()
        return !upcomingReminders.contains { $0.procedureName.lowercased() == name }
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
