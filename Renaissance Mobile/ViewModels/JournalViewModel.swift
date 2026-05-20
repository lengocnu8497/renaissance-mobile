//
//  JournalViewModel.swift
//  Renaissance Mobile
//

import Foundation
import Observation
import Supabase

struct RecoveryScoreSnapshot {
    let score: Int
    let consistencyRate: Int
    let symptomTrend: TrendDirection
    let dayNumber: Int
}

struct SmartRecoveryAlert: Identifiable {
    let id: String
    let severity: FlagSeverity
    let title: String
    let message: String
}

struct JournalAlertSnapshot: Identifiable {
    let id: String
    let severity: FlagSeverity
    let title: String
    let body: String
    let metric: String?
    let source: Source

    enum Source {
        case weeklySummary
        case localHeuristic
    }
}

struct JournalWeeklyReportPreview {
    let weekNumber: Int
    let title: String
    let subtitle: String
    let statusLabel: String
    let progress: Int
    let actionTitle: String
    let summary: WeeklySummary?
}

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
    /// Display name for the bootstrapped procedure (mirrors bootstrappedProcedureId)
    var bootstrappedProcedureName: String?
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
    var weeklyStates: [String: [WeeklyCheckIn]] = [:]

    // MARK: - Services

    private let journalService: any JournalServiceProtocol
    private let insightsService: any RecoveryInsightsServiceProtocol
    private let weeklySummaryService = WeeklySummaryService()
    private let usageService = UsageTrackingService(supabase: supabase)

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
            await bootstrapCheckInsIfNeeded()
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func bootstrapWeeklyState(
        procedureId: String,
        procedureName: String,
        startDate: Date
    ) async {
        if let existing = weeklyStates[procedureId], !existing.isEmpty {
            return
        }

        do {
            let states = try await weeklySummaryService.bootstrapWeeks(
                procedureId: procedureId,
                procedureName: procedureName,
                startDate: startDate
            )
            weeklyStates[procedureId] = states
            await WeeklyCheckInService.shared.scheduleNotifications(
                for: states,
                procedureName: procedureName
            )
        } catch {
            print("Weekly state bootstrap failed for \(procedureName): \(error)")
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
        painLevel: Int? = nil,
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
                painLevel: painLevel,
                bruisingLevel: bruisingLevel,
                swellingLevel: swellingLevel,
                rednessLevel: rednessLevel
            )
            entries.insert(entry, at: 0)
            if !hasEverLoggedEntry { hasEverLoggedEntry = true }
            // Once the user has a real journal entry, the persisted bootstrap is no longer needed.
            if bootstrappedProcedureId == entry.procedureId {
                bootstrappedProcedureId   = nil
                bootstrappedProcedureName = nil
                OnboardingStore.clearBootstrappedProcedure()
            }

            let procedureEntries = entries.filter { $0.procedureId == entry.procedureId }
            if procedureEntries.count == 1 {
                await bootstrapWeeklyState(
                    procedureId: entry.procedureId,
                    procedureName: entry.procedureName,
                    startDate: entry.entryDateAsDate
                )
            }

            if let pending = firstIncompleteWeeklyState(for: entry.procedureId) {
                do {
                    try await weeklySummaryService.updateCompletion(
                        procedureId: entry.procedureId,
                        weekNumber: pending.weekNumber,
                        entryId: entry.id
                    )
                    weeklyStates[entry.procedureId] = try await weeklySummaryService.fetchWeeklyStates(procedureId: entry.procedureId)
                    if insightsEnabled {
                        await refreshWeeklySummary(
                            for: entry.procedureId,
                            procedureName: entry.procedureName,
                            weekNumber: pending.weekNumber
                        )
                    }
                } catch {
                    print("Weekly completion sync failed for \(entry.procedureName): \(error)")
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

    // MARK: - Credit Pre-check

    /// Returns false if the user's remaining credits are below `cost`.
    /// Best-effort — returns true on any fetch error so the server remains the hard gate.
    private func hasCreditsAvailable(_ cost: Int) async -> Bool {
        do {
            let usage = try await usageService.getCurrentUsage()
            return (usage.creditsUsed + cost) <= usage.creditsLimit
        } catch {
            return true
        }
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
        guard await hasCreditsAvailable(2) else {
            print("RecoveryInsights: insufficient credits for \(procedureName), skipping")
            return
        }

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
        guard let primaryId = primaryProcedureId else { return nil }
        return insights[primaryId]
    }

    var isPrimaryGenerating: Bool {
        guard let primaryId = primaryProcedureId else { return false }
        return insightsGenerating.contains(primaryId)
    }

    var hasLoggedToday: Bool {
        let today = Self.isoDateFormatter.string(from: Date())
        return entries.contains { $0.entryDate == today }
    }

    var primaryProcedureId: String? {
        groupedByProcedure.max(by: { $0.entries.count < $1.entries.count })?.entries.first?.procedureId
            ?? bootstrappedProcedureId
    }

    var primaryProcedureName: String? {
        groupedByProcedure.max(by: { $0.entries.count < $1.entries.count })?.key
            ?? bootstrappedProcedureName
    }

    var primaryProcedureEntries: [JournalEntry] {
        guard let primaryProcedureId else { return [] }
        return entries
            .filter { $0.procedureId == primaryProcedureId }
            .sorted { $0.dayNumber < $1.dayNumber }
    }

    var primaryRecoveryScore: RecoveryScoreSnapshot? {
        let procedureEntries = primaryProcedureEntries
        guard !procedureEntries.isEmpty else { return nil }

        let allMetrics = procedureEntries.flatMap {
            [$0.painLevel, $0.swellingLevel, $0.bruisingLevel, $0.rednessLevel]
        }
        .compactMap { $0 }
        let burden = allMetrics.isEmpty ? 4.0 : allMetrics.reduce(0, +) / Double(allMetrics.count)
        let consistencyRate = min(100, max(0, Int((Double(streak) / 7.0) * 100)))
        let symptomScore = max(0, min(100, Int((10 - burden) * 10)))
        let score = max(0, min(100, Int((Double(symptomScore) * 0.75) + (Double(consistencyRate) * 0.25))))

        return RecoveryScoreSnapshot(
            score: score,
            consistencyRate: consistencyRate,
            symptomTrend: trendDirection(for: procedureEntries),
            dayNumber: procedureEntries.last?.dayNumber ?? 0
        )
    }

    var primarySmartAlerts: [SmartRecoveryAlert] {
        smartAlerts(for: primaryProcedureEntries)
    }

    var primaryPhotoTimeline: [JournalEntry] {
        let photoEntries = primaryProcedureEntries.filter { $0.photoUrl != nil || $0.photoPath != nil }
        guard !photoEntries.isEmpty else { return [] }

        let sorted = photoEntries.sorted { $0.dayNumber < $1.dayNumber }
        if sorted.count <= 3 { return sorted }

        let middleIndex = sorted.count / 2
        return [sorted.first, sorted[middleIndex], sorted.last].compactMap { $0 }
    }

    var primaryPainSeries: [Int] {
        primaryProcedureEntries.compactMap { entry in
            entry.painLevel.map { Int($0.rounded()) }
        }
    }

    var latestEntry: JournalEntry? {
        primaryProcedureEntries.max(by: { $0.entryDateAsDate < $1.entryDateAsDate })
    }

    func recentEntries(limit: Int = 3) -> [JournalEntry] {
        Array(
            primaryProcedureEntries
                .sorted { $0.entryDateAsDate > $1.entryDateAsDate }
                .prefix(limit)
        )
    }

    var latestPainLevel: Int? {
        latestEntry?.painLevel.map { Int($0.rounded()) }
    }

    var latestSwellingLevel: Int? {
        latestEntry?.swellingLevel.map { Int($0.rounded()) }
    }

    var latestBruisingLevel: Int? {
        latestEntry?.bruisingLevel.map { Int($0.rounded()) }
    }

    var latestRednessLevel: Int? {
        latestEntry?.rednessLevel.map { Int($0.rounded()) }
    }

    func photoReelEntries(limit: Int = 6) -> [JournalEntry] {
        Array(
            primaryProcedureEntries
                .filter { $0.photoUrl != nil || $0.photoPath != nil }
                .sorted { $0.entryDateAsDate > $1.entryDateAsDate }
                .prefix(limit)
        )
    }

    var journalAlert: JournalAlertSnapshot? {
        if let remoteAlert = bestWeeklyAlert {
            return JournalAlertSnapshot(
                id: remoteAlert.id,
                severity: remoteAlert.severity,
                title: remoteAlert.title,
                body: [remoteAlert.explanation, remoteAlert.recommendedNextStep]
                    .compactMap { $0 }
                    .joined(separator: " "),
                metric: remoteAlert.metric,
                source: .weeklySummary
            )
        }

        if let localAlert = primarySmartAlerts.sorted(by: Self.alertSeverityRank).first {
            return JournalAlertSnapshot(
                id: localAlert.id,
                severity: localAlert.severity,
                title: localAlert.title,
                body: localAlert.message,
                metric: nil,
                source: .localHeuristic
            )
        }

        return nil
    }

    var weeklyReportProgress: Int {
        guard let previewWeekNumber else { return 0 }
        if weeklySummary(for: previewWeekNumber) != nil { return 100 }

        let entries = entries(forWeekNumber: previewWeekNumber)
        guard let targetCheckIn = previewCheckIn else { return 0 }

        if targetCheckIn.isCompleted {
            return 90
        }
        guard !entries.isEmpty else { return 0 }

        var progress = 0

        progress += min(entries.count, 3) >= 3 ? 35 : Int((Double(entries.count) / 3.0) * 35.0)

        let metricsLogs = entries.filter { $0.hasRecoveryMetrics }.count
        progress += min(metricsLogs, 2) >= 2 ? 25 : Int((Double(metricsLogs) / 2.0) * 25.0)

        let photoLogs = entries.contains { $0.photoUrl != nil || $0.photoPath != nil }
        if photoLogs { progress += 20 }

        let noteLogs = entries.filter {
            guard let notes = $0.notes?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            return !notes.isEmpty
        }.count
        progress += min(noteLogs, 2) >= 2 ? 20 : Int((Double(noteLogs) / 2.0) * 20.0)

        return min(progress, 100)
    }

    var weeklyReportPreview: JournalWeeklyReportPreview? {
        guard let weekNumber = previewWeekNumber else { return nil }

        if let readySummary = weeklySummary(for: weekNumber) {
            return JournalWeeklyReportPreview(
                weekNumber: readySummary.weekNumber,
                title: "Week \(readySummary.weekNumber) report ready",
                subtitle: readySummary.headline,
                statusLabel: "Ready",
                progress: 100,
                actionTitle: "Open report",
                summary: readySummary
            )
        }

        let progress = weeklyReportProgress
        let statusLabel: String
        let title: String
        let subtitle: String
        let actionTitle: String

        if let previewCheckIn, previewCheckIn.isCompleted {
            statusLabel = "Processing"
            title = "Week \(weekNumber) report is generating"
            subtitle = "Your check-in is complete. We're turning this week's logs into a report now."
            actionTitle = "View progress"
        } else {
            switch progress {
            case 80...99:
                statusLabel = "Almost ready"
            case 40...79:
                statusLabel = "Building"
            default:
                statusLabel = "Getting started"
            }
            title = "Week \(weekNumber) report \(statusLabel.lowercased())"
            subtitle = "Your daily logs are shaping this week's recovery summary automatically."
            actionTitle = "View progress"
        }

        return JournalWeeklyReportPreview(
            weekNumber: weekNumber,
            title: title,
            subtitle: subtitle,
            statusLabel: statusLabel,
            progress: progress,
            actionTitle: actionTitle,
            summary: nil
        )
    }

    // MARK: - Weekly Check-In

    /// Pending check-in for the primary procedure (most entries), if any.
    /// Falls back to bootstrappedProcedureId when no journal entries exist yet.
    var primaryPendingCheckIn: WeeklyCheckIn? {
        guard let primaryId = primaryProcedureId else { return nil }
        return firstIncompleteWeeklyState(for: primaryId)
    }

    /// All check-ins for a given procedure (for the progress strip).
    func checkIns(for procedureId: String) -> [WeeklyCheckIn] {
        weeklyStates[procedureId] ?? []
    }

    /// Bootstrap check-ins for any procedure that has entries but no schedule yet.
    /// Call once after load() completes.
    @MainActor
    func bootstrapCheckInsIfNeeded() async {
        for group in groupedByProcedure {
            guard let earliest = group.entries.min(by: { $0.entryDateAsDate < $1.entryDateAsDate }) else { continue }
            await bootstrapWeeklyState(
                procedureId: earliest.procedureId,
                procedureName: group.key,
                startDate: earliest.entryDateAsDate
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
            let checkIns = checkIns(for: procedureId)
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

    @MainActor
    func loadRemoteWeeklySummaries() async {
        guard insightsEnabled else { return }
        for group in groupedByProcedure {
            guard let procedureId = group.entries.first?.procedureId else { continue }
            do {
                let remoteContent = try await weeklySummaryService.fetchRemoteContent(procedureId: procedureId)
                for summary in remoteContent.summaries {
                    weeklySummaries[weeklySummaryKey(procedureId, summary.weekNumber)] = summary
                }
                weeklyStates[procedureId] = remoteContent.states
            } catch {
                print("Remote weekly summary load failed for \(group.key): \(error)")
            }
        }
    }

    func clearAIOutputs() {
        insights.removeAll()
        insightsGenerating.removeAll()
        weeklySummaries.removeAll()
        weeklySummaryGenerating.removeAll()
    }

    /// Generates a weekly summary for the given procedure week.
    /// Non-fatal: errors are logged, not surfaced to the user.
    @MainActor
    func refreshWeeklySummary(for procedureId: String, procedureName: String, weekNumber: Int) async {
        guard insightsEnabled else { return }
        let key = weeklySummaryKey(procedureId, weekNumber)
        guard !weeklySummaryGenerating.contains(key) else { return }

        guard await hasCreditsAvailable(1) else {
            print("WeeklySummary: insufficient credits for wk\(weekNumber) \(procedureName), skipping")
            return
        }

        weeklySummaryGenerating.insert(key)
        defer { weeklySummaryGenerating.remove(key) }

        let procedureEntries = entries.filter { $0.procedureId == procedureId }
        guard !procedureEntries.isEmpty else { return }
        guard let checkIn = checkIns(for: procedureId).first(where: { $0.weekNumber == weekNumber }) else { return }

        do {
            let summary = try await weeklySummaryService.generateSummary(
                procedureId: procedureId,
                procedureName: procedureName,
                weekNumber: weekNumber,
                scheduledDate: checkIn.scheduledDate,
                completedEntryId: checkIn.completedEntryId,
                entries: procedureEntries
            )
            weeklySummaries[key] = summary
            weeklyStates[procedureId] = try await weeklySummaryService.fetchWeeklyStates(procedureId: procedureId)
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

    func weeklySatisfaction(for procedureId: String, weekNumber: Int) -> Int? {
        checkIns(for: procedureId)
            .first(where: { $0.weekNumber == weekNumber })?
            .satisfactionRating
    }

    func setWeeklySatisfaction(_ rating: Int, for procedureId: String, weekNumber: Int) {
        Task { @MainActor in
            do {
                try await weeklySummaryService.updateSatisfaction(
                    procedureId: procedureId,
                    weekNumber: weekNumber,
                    rating: rating
                )
                weeklyStates[procedureId] = try await weeklySummaryService.fetchWeeklyStates(procedureId: procedureId)
                if let summary = weeklySummaries[weeklySummaryKey(procedureId, weekNumber)] {
                    weeklySummaries[weeklySummaryKey(procedureId, weekNumber)] = WeeklySummary(
                        weekNumber: summary.weekNumber,
                        headline: summary.headline,
                        observation: summary.observation,
                        improvement: summary.improvement,
                        concern: summary.concern,
                        painTrend: summary.painTrend,
                        swellingStatus: summary.swellingStatus,
                        bruisingStatus: summary.bruisingStatus,
                        rednessStatus: summary.rednessStatus,
                        recoveryScore: summary.recoveryScore,
                        consistencyRate: summary.consistencyRate,
                        alerts: summary.alerts,
                        metricPoints: summary.metricPoints,
                        scheduledDate: summary.scheduledDate,
                        completedEntryId: summary.completedEntryId,
                        isCompleted: summary.isCompleted,
                        satisfactionRating: rating,
                        procedureId: summary.procedureId,
                        generatedAt: summary.generatedAt
                    )
                }
            } catch {
                print("Weekly satisfaction sync failed: \(error)")
            }
        }
    }

    private func smartAlerts(for entries: [JournalEntry]) -> [SmartRecoveryAlert] {
        guard !entries.isEmpty else { return [] }

        var alerts: [SmartRecoveryAlert] = []

        let recentPain = entries.compactMap(\.painLevel)
        if isIncreasingThreeDays(recentPain) {
            alerts.append(
                SmartRecoveryAlert(
                    id: "pain-rise",
                    severity: .warning,
                    title: "Pain is climbing",
                    message: "Your pain has increased across your last 3 logs. This can happen during a tougher stretch, but if it rises again tomorrow, consider contacting your provider."
                )
            )
        }

        let recentSwelling = entries.compactMap(\.swellingLevel)
        if isIncreasingThreeDays(recentSwelling) {
            alerts.append(
                SmartRecoveryAlert(
                    id: "swelling-rise",
                    severity: .warning,
                    title: "Swelling is trending up",
                    message: "Swelling has increased for 3 straight logs. If it worsens again tomorrow or feels sudden, check in with your provider."
                )
            )
        }

        let recentBruising = entries.compactMap(\.bruisingLevel)
        if let last = recentBruising.last, last >= 7 {
            alerts.append(
                SmartRecoveryAlert(
                    id: "bruising-high",
                    severity: .info,
                    title: "Bruising is still elevated",
                    message: "Bruising is still on the higher side in your latest log. Keep tracking it so Rena can tell whether it is settling or lingering."
                )
            )
        }

        return alerts
    }

    private func isIncreasingThreeDays(_ values: [Double]) -> Bool {
        guard values.count >= 3 else { return false }
        let recent = Array(values.suffix(3))
        return recent[0] < recent[1] && recent[1] < recent[2]
    }

    private func firstIncompleteWeeklyState(for procedureId: String) -> WeeklyCheckIn? {
        checkIns(for: procedureId)
            .filter { !$0.isCompleted && $0.scheduledDate <= Date() }
            .sorted { $0.weekNumber < $1.weekNumber }
            .first
    }

    private var previewCheckIn: WeeklyCheckIn? {
        if let primaryProcedureId {
            let states = checkIns(for: primaryProcedureId).sorted { $0.weekNumber < $1.weekNumber }
            return states.first(where: { !$0.isCompleted && $0.scheduledDate <= Date() })
                ?? states.first(where: { !$0.isCompleted })
                ?? states.last(where: { $0.isCompleted })
        }
        return nil
    }

    private var previewWeekNumber: Int? {
        previewCheckIn?.weekNumber
    }

    private var latestWeeklySummary: WeeklySummary? {
        guard let primaryProcedureId else { return nil }

        return weeklySummaries
            .values
            .filter { $0.procedureId == primaryProcedureId }
            .sorted { lhs, rhs in
                if lhs.weekNumber == rhs.weekNumber {
                    return lhs.generatedAt > rhs.generatedAt
                }
                return lhs.weekNumber > rhs.weekNumber
            }
            .first
    }

    private var bestWeeklyAlert: RecoveryAlert? {
        if let previewWeekNumber, let activeSummary = weeklySummary(for: previewWeekNumber) {
            return activeSummary.alerts.sorted(by: Self.alertSeverityRank).first
        }
        return latestWeeklySummary?.alerts.sorted(by: Self.alertSeverityRank).first
    }

    private func weeklySummary(for weekNumber: Int) -> WeeklySummary? {
        guard let primaryProcedureId else { return nil }
        return weeklySummaries[weeklySummaryKey(primaryProcedureId, weekNumber)]
    }

    private func entries(forWeekNumber weekNumber: Int) -> [JournalEntry] {
        let startDay = max(0, (weekNumber - 1) * 7)
        let endDay = (weekNumber * 7) - 1
        return primaryProcedureEntries.filter { $0.dayNumber >= startDay && $0.dayNumber <= endDay }
    }

    private func trendDirection(for entries: [JournalEntry]) -> TrendDirection {
        let latestBurden = metricBurden(for: entries.suffix(2))
        let earlyBurden = metricBurden(for: entries.prefix(2))
        let delta = latestBurden - earlyBurden
        if delta <= -0.75 { return .improving }
        if delta >= 0.75 { return .concerning }
        return .stable
    }

    private func metricBurden<C: Collection>(for entries: C) -> Double where C.Element == JournalEntry {
        let metrics = entries.flatMap { [$0.painLevel, $0.swellingLevel, $0.bruisingLevel, $0.rednessLevel] }
            .compactMap { $0 }
        guard !metrics.isEmpty else { return 4.0 }
        return metrics.reduce(0, +) / Double(metrics.count)
    }

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func alertSeverityRank(_ lhs: RecoveryAlert, _ rhs: RecoveryAlert) -> Bool {
        severityRank(lhs.severity) > severityRank(rhs.severity)
    }

    private static func alertSeverityRank(_ lhs: SmartRecoveryAlert, _ rhs: SmartRecoveryAlert) -> Bool {
        severityRank(lhs.severity) > severityRank(rhs.severity)
    }

    private static func severityRank(_ severity: FlagSeverity) -> Int {
        switch severity {
        case .urgent: return 3
        case .warning: return 2
        case .info: return 1
        }
    }
}
