//
//  RecoveryPlanService.swift
//  Renaissance Mobile
//

import CryptoKit
import Foundation
import Supabase

enum RecoveryPlanServiceError: LocalizedError {
    case notAuthenticated
    case missingProcedureContext

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be signed in to build a recovery plan."
        case .missingProcedureContext:
            return "We need your procedure and timing before we can build a personalized recovery plan."
        }
    }
}

@MainActor
final class RecoveryPlanService {
    private let profileService: UserProfileService
    private let timelineResolver: RecoveryPlanTimelineResolver
    private let calendar: Calendar
    private let planVersion: Int

    init(
        profileService: UserProfileService? = nil,
        timelineResolver: RecoveryPlanTimelineResolver? = nil,
        calendar: Calendar = .current,
        planVersion: Int = 1
    ) {
        self.profileService = profileService ?? UserProfileService(supabase: supabase)
        self.timelineResolver = timelineResolver ?? RecoveryPlanTimelineResolver(calendar: calendar)
        self.calendar = calendar
        self.planVersion = planVersion
    }

    func loadOrGeneratePlan(
        journalViewModel: JournalViewModel? = nil,
        forceRefresh: Bool = false,
        referenceDate: Date = Date()
    ) async throws -> PersonalizedRecoveryPlan {
        try await generatePlan(
            journalViewModel: journalViewModel,
            forceRefresh: forceRefresh,
            referenceDate: referenceDate
        )
    }

    func generatePlan(
        journalViewModel: JournalViewModel? = nil,
        forceRefresh: Bool = false,
        referenceDate: Date = Date()
    ) async throws -> PersonalizedRecoveryPlan {
        _ = forceRefresh
        return try await currentPreviewPlan(
            journalViewModel: journalViewModel,
            referenceDate: referenceDate
        )
    }

    func currentPreviewPlan(
        journalViewModel: JournalViewModel? = nil,
        referenceDate: Date = Date()
    ) async throws -> PersonalizedRecoveryPlan {
        guard let userId = supabase.auth.currentUser?.id else {
            throw RecoveryPlanServiceError.notAuthenticated
        }

        let context = try await resolvedContext(
            journalViewModel: journalViewModel,
            referenceDate: referenceDate
        )
        let inputHash = try makeInputHash(from: context.input)

        var phases = [RecoveryPlanPhase]()
        phases.reserveCapacity(context.timeline.phases.count)

        for phase in context.timeline.phases {
            let generatedPhase = await makePlanPhase(
                from: phase,
                input: context.input,
                journalSignals: context.input.latestJournalSignals
            )
            phases.append(generatedPhase)
        }

        let currentPhase = phases.first(where: { $0.status == .current }) ?? phases.last ?? makeFallbackPhase(
            for: context.input
        )

        let plan = PersonalizedRecoveryPlan(
            id: UUID(),
            userId: userId,
            procedureName: context.procedureName,
            procedureId: context.procedureId,
            procedureDate: context.procedureDate,
            generatedAt: referenceDate,
            planVersion: planVersion,
            inputHash: inputHash,
            currentPhase: currentPhase,
            phases: phases,
            personalizationSummary: buildPersonalizationSummary(from: context.input),
            disclaimers: buildDisclaimers(for: context.input.procedureFamily)
        )

        await persistPlanCacheIfNeeded(plan)
        return plan
    }

    func buildInput(
        journalViewModel: JournalViewModel? = nil,
        referenceDate: Date = Date()
    ) async throws -> RecoveryPlanInput {
        try await resolvedContext(
            journalViewModel: journalViewModel,
            referenceDate: referenceDate
        ).input
    }

    private func resolvedContext(
        journalViewModel: JournalViewModel?,
        referenceDate: Date
    ) async throws -> ResolvedRecoveryPlanContext {
        let profile = await loadCurrentProfileIfAvailable()
        let procedureContext = resolveProcedureContext(
            journalViewModel: journalViewModel,
            profile: profile
        )

        guard let procedureName = procedureContext.name,
              let procedureDate = procedureContext.date else {
            throw RecoveryPlanServiceError.missingProcedureContext
        }

        let timeline = timelineResolver.resolveTimeline(
            procedureName: procedureName,
            procedureDate: procedureDate,
            referenceDate: referenceDate
        )

        let input = RecoveryPlanInput(
            procedureName: procedureName,
            procedureDate: procedureDate,
            daysSinceProcedure: timeline.daysSinceProcedure,
            currentWeek: timeline.currentWeek,
            currentPhaseTitle: timeline.currentPhase.title,
            procedureFamily: timeline.procedureFamily,
            gender: firstNonEmpty(OnboardingStore.pendingGender, profile?.gender),
            ageRange: firstNonEmpty(OnboardingStore.pendingAgeRange, profile?.ageRange),
            raceEthnicity: firstNonEmpty(OnboardingStore.pendingRaceEthnicity, profile?.raceEthnicity),
            aestheticGoals: mergeUnique(OnboardingStore.pendingAestheticGoals, profile?.aestheticGoals),
            bodyAreas: mergeUnique(OnboardingStore.pendingBodyAreas, profile?.bodyAreasOfInterest),
            proceduresOfInterest: mergeUnique(OnboardingStore.pendingProceduresOfInterest, profile?.proceduresOfInterest),
            previousProcedures: mergeUnique(OnboardingStore.pendingPreviousProcedures, profile?.previousProcedures),
            healthFlags: mergeUnique(OnboardingStore.pendingHealthFlags, profile?.healthFlags),
            latestJournalSignals: journalSignals(from: journalViewModel)
        )

        return ResolvedRecoveryPlanContext(
            procedureName: procedureName,
            procedureId: procedureContext.id,
            procedureDate: procedureDate,
            timeline: timeline,
            input: input
        )
    }

    private func loadCurrentProfileIfAvailable() async -> UserProfile? {
        do {
            return try await profileService.getUserProfile()
        } catch {
            print("RecoveryPlanService profile fallback: \(error)")
            return nil
        }
    }

    private func resolveProcedureContext(
        journalViewModel: JournalViewModel?,
        profile: UserProfile?
    ) -> ProcedureContext {
        let journalProcedureName = journalViewModel?.primaryProcedureName
        let journalProcedureId = journalViewModel?.primaryProcedureId
        let earliestJournalDate = journalViewModel?.primaryProcedureEntries
            .map(\.entryDateAsDate)
            .min()

        let procedureName = firstNonEmpty(
            OnboardingStore.pendingProcedureName,
            journalProcedureName,
            OnboardingStore.savedBootstrappedProcedureName,
            profile?.proceduresOfInterest?.first
        )

        let procedureDate = earliestNonNil(
            OnboardingStore.pendingProcedureDate,
            earliestJournalDate
        )

        let procedureId = firstNonEmpty(
            journalProcedureId,
            OnboardingStore.savedBootstrappedProcedureId,
            procedureName.map(slugifyProcedureName)
        )

        return ProcedureContext(
            id: procedureId,
            name: procedureName,
            date: procedureDate
        )
    }

    private func journalSignals(from journalViewModel: JournalViewModel?) -> RecoveryPlanJournalSignals? {
        guard let journalViewModel else { return nil }

        let entryCount = journalViewModel.primaryProcedureEntries.count
        let weeklySummaryHeadline = journalViewModel.weeklyReportPreview?.summary?.headline
        let activeAlerts = [journalViewModel.journalAlert?.title].compactMap { $0 }

        guard entryCount > 0
            || journalViewModel.latestPainLevel != nil
            || journalViewModel.latestSwellingLevel != nil
            || journalViewModel.latestBruisingLevel != nil
            || journalViewModel.latestRednessLevel != nil
            || weeklySummaryHeadline != nil
            || !activeAlerts.isEmpty
        else {
            return nil
        }

        return RecoveryPlanJournalSignals(
            entryCount: entryCount,
            latestPainLevel: journalViewModel.latestPainLevel,
            latestSwellingLevel: journalViewModel.latestSwellingLevel,
            latestBruisingLevel: journalViewModel.latestBruisingLevel,
            latestRednessLevel: journalViewModel.latestRednessLevel,
            weeklySummaryHeadline: weeklySummaryHeadline,
            activeAlerts: activeAlerts
        )
    }

    private func makePlanPhase(
        from timelinePhase: RecoveryPlanTimelinePhase,
        input: RecoveryPlanInput,
        journalSignals: RecoveryPlanJournalSignals?
    ) async -> RecoveryPlanPhase {
        let summary = makePhaseSummary(
            timelinePhase: timelinePhase,
            input: input,
            journalSignals: journalSignals
        )
        let focusAreas = makeFocusAreas(
            for: timelinePhase,
            input: input,
            journalSignals: journalSignals
        )

        return RecoveryPlanPhase(
            id: timelinePhase.id,
            title: timelinePhase.title,
            weekStart: timelinePhase.weekStart,
            weekEnd: timelinePhase.weekEnd,
            status: timelinePhase.status,
            summary: summary,
            expectations: makeExpectations(for: timelinePhase, input: input),
            focusAreas: focusAreas,
            photoPrompts: makePhotoPrompts(for: timelinePhase, input: input),
            providerQuestions: makeProviderQuestions(for: timelinePhase, input: input),
            watchFors: makeWatchFors(for: timelinePhase, input: input, journalSignals: journalSignals),
            encouragement: makeEncouragement(for: timelinePhase, input: input)
        )
    }

    private func makeFallbackPhase(for input: RecoveryPlanInput) -> RecoveryPlanPhase {
        RecoveryPlanPhase(
            id: "fallback-current-phase",
            title: input.currentPhaseTitle,
            weekStart: input.currentWeek,
            weekEnd: input.currentWeek,
            status: .current,
            summary: "Your roadmap starts from where you are now and focuses on the next most useful recovery milestones.",
            expectations: [
                "Use weekly comparisons instead of judging daily swings.",
                "Keep logging symptoms and photos consistently so progress is easier to interpret."
            ],
            focusAreas: [
                "Track the details that matter most this week.",
                "Save questions for your next follow-up while changes are fresh."
            ],
            photoPrompts: [
                "Take one well-lit front-facing photo this week.",
                "Capture the same angle and distance for easier comparison."
            ],
            providerQuestions: [
                "What changes are most realistic to expect over the next few weeks?"
            ],
            watchFors: [
                "Any symptom jump that feels meaningfully worse instead of gradually settling."
            ],
            encouragement: "You do not need to restart at week one. This roadmap is anchored to your current recovery stage."
        )
    }

    private func makePhaseSummary(
        timelinePhase: RecoveryPlanTimelinePhase,
        input: RecoveryPlanInput,
        journalSignals: RecoveryPlanJournalSignals?
    ) -> String {
        timelinePhase.summary
    }

    private func makeExpectations(
        for phase: RecoveryPlanTimelinePhase,
        input: RecoveryPlanInput
    ) -> [String] {
        var items = [
            "Visible changes usually make more sense when compared week to week rather than day to day.",
            "Your plan should focus on the next realistic milestone for \(input.procedureName), not on early-stage expectations that no longer apply."
        ]

        switch input.procedureFamily {
        case .rhinoplasty:
            items.append("Swelling can shift unevenly, especially later in the day, even when the overall trend is improving.")
        case .breastSurgery:
            items.append("Shape, tightness, and position can still evolve across several weeks before looking more settled.")
        case .bodyContouring:
            items.append("Contour changes often emerge gradually, and early swelling can hide progress.")
        case .facialSurgery:
            items.append("You may feel more presentable before everything feels soft, symmetrical, or fully natural.")
        case .other:
            items.append("Keep expectations tied to your current phase and follow-up plan rather than a rigid generic timeline.")
        }

        if phase.status == .completed {
            items = [
                "This phase is part of your completed recovery history and is useful mainly for comparison.",
                "Review it if you want context for how far you have already come."
            ]
        }

        return items
    }

    private func makeFocusAreas(
        for phase: RecoveryPlanTimelinePhase,
        input: RecoveryPlanInput,
        journalSignals: RecoveryPlanJournalSignals?
    ) -> [String] {
        var items = [
            currentPhaseTrackingBullet(for: input),
            currentPhasePersistenceBullet(for: input)
        ]

        if let healthBullet = currentPhaseHealthBullet(for: input) {
            items.append(healthBullet)
        }

        if let goalsBullet = currentPhaseGoalBullet(for: input) {
            items.append(goalsBullet)
        }

        if let priorProcedureBullet = currentPhasePreviousProceduresBullet(for: input) {
            items.append(priorProcedureBullet)
        }

        if let journalSignals, journalSignals.entryCount >= 3 {
            items.append("You already have enough history logged to compare broader patterns instead of isolated entries.")
        }

        if phase.status == .completed {
            items = ["Archive this stage as context and keep your attention on the current phase."]
        }

        return items
    }

    private func makePhotoPrompts(
        for phase: RecoveryPlanTimelinePhase,
        input: RecoveryPlanInput
    ) -> [String] {
        var prompts = [
            "Take one photo in bright, indirect light from the same angle you used last time.",
            "Keep distance, posture, and expression consistent so changes are easier to compare."
        ]

        switch input.procedureFamily {
        case .rhinoplasty, .facialSurgery:
            prompts.append("Capture front and profile angles this week if swelling or asymmetry is one of your concerns.")
        case .breastSurgery:
            prompts.append("Use the same mirror height and support garments so shape changes are not distorted.")
        case .bodyContouring:
            prompts.append("Take front, side, and quarter-turn photos to compare contour trends more reliably.")
        case .other:
            prompts.append("Choose one consistent view that best reflects the area you care about most.")
        }

        return prompts
    }

    private func makeProviderQuestions(
        for phase: RecoveryPlanTimelinePhase,
        input: RecoveryPlanInput
    ) -> [String] {
        var questions = [
            "Based on where I am now, what changes are still expected over the next few weeks?",
            "Is anything I’m noticing now normal for this stage of recovery?"
        ]

        if !input.previousProcedures.isEmpty {
            questions.append("Does my prior procedure history change how I should interpret this stage?")
        }

        if !input.healthFlags.isEmpty {
            questions.append("Do any of my health considerations change what you want me to watch more closely?")
        }

        if phase.status == .upcoming {
            questions.append("What should I plan for before I enter this next phase?")
        }

        return questions
    }

    private func makeWatchFors(
        for phase: RecoveryPlanTimelinePhase,
        input: RecoveryPlanInput,
        journalSignals: RecoveryPlanJournalSignals?
    ) -> [String] {
        var items = [
            "A sudden setback that feels notably worse instead of gradually improving.",
            "Persistent asymmetry, swelling, or discomfort that is increasing rather than settling."
        ]

        if let alertTitle = journalSignals?.activeAlerts.first {
            items.append("Keep an eye on the trend that surfaced in your recent logs: \(alertTitle).")
        }

        if let pain = journalSignals?.latestPainLevel, pain >= 7 {
            items.append("Your recent pain score has been elevated, so worsening discomfort deserves extra attention.")
        }

        if phase.status == .completed {
            items = ["Completed phases are reference points only; focus your watch list on current or upcoming changes."]
        }

        return items
    }

    private func makeEncouragement(
        for phase: RecoveryPlanTimelinePhase,
        input: RecoveryPlanInput
    ) -> String? {
        switch phase.status {
        case .completed:
            return "This phase is behind you now. Use it as perspective, not as a benchmark you need to relive."
        case .current:
            return "This plan starts at week \(input.currentWeek), so the guidance is built around where your recovery actually is today."
        case .upcoming:
            return "Seeing the next phase ahead of time can make the recovery curve feel more manageable and less surprising."
        }
    }

    private func currentPhaseOpening(for input: RecoveryPlanInput) -> String {
        let concern = likelyConcern(for: input)
        let area = primaryBodyAreaPhrase(for: input)

        switch input.procedureFamily {
        case .rhinoplasty:
            return "At this stage of \(input.procedureName.lowercased()), the focus shifts from early protection into tracking how swelling, symmetry, and shape are settling\(area.map { " around your \($0)" } ?? ""). \(concern)"
        case .breastSurgery:
            return "At this stage of \(input.procedureName.lowercased()), the main question is how shape, tightness, and position are evolving\(area.map { " across your \($0)" } ?? ""). \(concern)"
        case .bodyContouring:
            return "At this stage of \(input.procedureName.lowercased()), progress is better judged by gradual contour change than by day-to-day fluctuation\(area.map { " in your \($0)" } ?? ""). \(concern)"
        case .facialSurgery:
            return "At this stage of \(input.procedureName.lowercased()), it is more useful to track softness, symmetry, and natural movement than to keep replaying the earliest recovery days\(area.map { " in your \($0)" } ?? ""). \(concern)"
        case .other:
            return "At this stage of \(input.procedureName.lowercased()), the plan should stay grounded in what is changing now\(area.map { " in your \($0)" } ?? ""). \(concern)"
        }
    }

    private func currentPhaseGoalLine(for input: RecoveryPlanInput) -> String? {
        guard !input.aestheticGoals.isEmpty else { return nil }

        let goals = humanizedList(input.aestheticGoals.prefix(2))
        return "Because you said you care most about \(goals.lowercased()), this phase should help you compare the details that matter to that outcome instead of scanning for every tiny change."
    }

    private func currentPhaseContextLine(for input: RecoveryPlanInput) -> String? {
        var clauses = [String]()

        if !input.previousProcedures.isEmpty {
            clauses.append("your prior history with \(humanizedList(input.previousProcedures.prefix(2)).lowercased())")
        }

        if !input.healthFlags.isEmpty {
            clauses.append("your health context around \(humanizedList(input.healthFlags.prefix(2)).lowercased())")
        }

        guard !clauses.isEmpty else { return nil }
        return "This copy also takes into account \(humanizedList(clauses)), so the guidance is not treating your recovery like a one-size-fits-all case."
    }

    private func currentPhaseTrackingBullet(for input: RecoveryPlanInput) -> String {
        if let area = primaryBodyAreaPhrase(for: input) {
            return "Stay consistent with photos and symptom logging so subtle trends are easier to spot in your \(area)."
        }
        return "Stay consistent with photos and symptom logging so subtle trends are easier to spot."
    }

    private func currentPhasePersistenceBullet(for input: RecoveryPlanInput) -> String {
        let concern = likelyConcernLabel(for: input)
        return "Keep notes on anything that feels surprisingly persistent, especially around \(concern), not just what feels dramatic."
    }

    private func currentPhaseHealthBullet(for input: RecoveryPlanInput) -> String? {
        guard !input.healthFlags.isEmpty else { return nil }
        return "Take your \(humanizedList(input.healthFlags.prefix(2)).lowercased()) into account when deciding what deserves an earlier provider follow-up."
    }

    private func currentPhaseGoalBullet(for input: RecoveryPlanInput) -> String? {
        guard !input.aestheticGoals.isEmpty else { return nil }
        return "Use your goals around \(humanizedList(input.aestheticGoals.prefix(2)).lowercased()) to decide what is worth comparing in photos this week."
    }

    private func currentPhasePreviousProceduresBullet(for input: RecoveryPlanInput) -> String? {
        guard !input.previousProcedures.isEmpty else { return nil }
        return "Since you have a history of \(humanizedList(input.previousProcedures.prefix(2)).lowercased()), keep track of anything that feels different from what you expected this time."
    }

    private func likelyConcern(for input: RecoveryPlanInput) -> String {
        switch input.procedureFamily {
        case .rhinoplasty:
            return "The most likely concern here is whether lingering swelling or asymmetry means anything important yet."
        case .breastSurgery:
            return "The most likely concern here is whether shape, tightness, or settling is still within a normal range."
        case .bodyContouring:
            return "The most likely concern here is whether swelling is still hiding progress or whether a contour difference is worth flagging."
        case .facialSurgery:
            return "The most likely concern here is whether lingering tightness, unevenness, or stiffness is still part of normal healing."
        case .other:
            return "The most likely concern here is whether the changes you are noticing still fit the expected rhythm of this stage."
        }
    }

    private func likelyConcernLabel(for input: RecoveryPlanInput) -> String {
        switch input.procedureFamily {
        case .rhinoplasty:
            return "swelling, asymmetry, and shape refinement"
        case .breastSurgery:
            return "shape, tightness, and settling"
        case .bodyContouring:
            return "swelling, contour definition, and symmetry"
        case .facialSurgery:
            return "tightness, symmetry, and natural movement"
        case .other:
            return "the changes most relevant to this stage"
        }
    }

    private func primaryBodyAreaPhrase(for input: RecoveryPlanInput) -> String? {
        guard let area = input.bodyAreas.first?.trimmingCharacters(in: .whitespacesAndNewlines), !area.isEmpty else {
            return nil
        }

        switch area.lowercased() {
        case "face":
            return "face"
        case "eyes / brow":
            return "eyes and brow"
        case "neck / jawline":
            return "neck and jawline"
        case "abdomen / waist":
            return "abdomen and waist"
        case "thighs / buttocks":
            return "thighs and buttocks"
        default:
            return area.lowercased()
        }
    }

    private func buildPersonalizationSummary(from input: RecoveryPlanInput) -> [String] {
        var items = [String]()

        items.append("Anchored to \(input.currentPhaseTitle.lowercased())")

        if !input.aestheticGoals.isEmpty {
            items.append("Shaped around your goals: \(humanizedList(input.aestheticGoals.prefix(3)))")
        }

        if !input.bodyAreas.isEmpty {
            items.append("Focused on \(humanizedList(input.bodyAreas.prefix(2)))")
        }

        if !input.previousProcedures.isEmpty {
            items.append("Accounts for your previous procedure history")
        }

        if !input.healthFlags.isEmpty {
            items.append("Adjusted for your health context")
        }

        if let journalSignals = input.latestJournalSignals, journalSignals.entryCount > 0 {
            items.append("Uses your logged recovery trend from \(journalSignals.entryCount) journal entries")
        }

        return items
    }

    private func buildDisclaimers(for family: RecoveryPlanProcedureFamily) -> [String] {
        var disclaimers = [
            "This roadmap is educational and supportive. It is not a diagnosis or a substitute for medical advice.",
            "If something feels urgent or meaningfully worse, contact your provider rather than relying on app guidance alone."
        ]

        if family == .rhinoplasty || family == .facialSurgery {
            disclaimers.append("Facial healing can look uneven during normal recovery, so use trends and follow-up guidance instead of daily visual judgment.")
        }

        return disclaimers
    }

    private func makeInputHash(from input: RecoveryPlanInput) throws -> String {
        let payload = RecoveryPlanHashPayload(
            procedureName: normalizedString(input.procedureName),
            procedureDate: iso8601DateOnly.string(from: input.procedureDate),
            daysSinceProcedure: input.daysSinceProcedure,
            currentWeek: input.currentWeek,
            currentPhaseTitle: normalizedString(input.currentPhaseTitle),
            procedureFamily: input.procedureFamily.rawValue,
            gender: normalizedOptional(input.gender),
            ageRange: normalizedOptional(input.ageRange),
            raceEthnicity: normalizedOptional(input.raceEthnicity),
            aestheticGoals: normalizedStrings(input.aestheticGoals),
            bodyAreas: normalizedStrings(input.bodyAreas),
            proceduresOfInterest: normalizedStrings(input.proceduresOfInterest),
            previousProcedures: normalizedStrings(input.previousProcedures),
            healthFlags: normalizedStrings(input.healthFlags),
            latestJournalSignals: normalizedJournalSignals(input.latestJournalSignals)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func normalizedJournalSignals(
        _ signals: RecoveryPlanJournalSignals?
    ) -> RecoveryPlanHashJournalSignals? {
        guard let signals else { return nil }
        return RecoveryPlanHashJournalSignals(
            entryCount: signals.entryCount,
            latestPainLevel: signals.latestPainLevel,
            latestSwellingLevel: signals.latestSwellingLevel,
            latestBruisingLevel: signals.latestBruisingLevel,
            latestRednessLevel: signals.latestRednessLevel,
            weeklySummaryHeadline: normalizedOptional(signals.weeklySummaryHeadline),
            activeAlerts: normalizedStrings(signals.activeAlerts)
        )
    }

    private func firstNonEmpty(_ candidates: String?...) -> String? {
        candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private func earliestNonNil(_ candidates: Date?...) -> Date? {
        candidates.compactMap { $0 }.min()
    }

    private func mergeUnique(_ local: [String], _ remote: [String]?) -> [String] {
        var seen = Set<String>()
        let merged = (local + (remote ?? [])).compactMap { raw -> String? in
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            let key = value.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return value
        }
        return merged
    }

    private func slugifyProcedureName(_ name: String) -> String {
        name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private func humanizedList<S: Sequence>(_ values: S) -> String where S.Element == String {
        let array = Array(values)
        switch array.count {
        case 0:
            return ""
        case 1:
            return array[0]
        case 2:
            return "\(array[0]) and \(array[1])"
        default:
            let prefix = array.dropLast().joined(separator: ", ")
            return "\(prefix), and \(array.last ?? "")"
        }
    }

    private func normalizedString(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedStrings(_ values: [String]) -> [String] {
        values
            .map(normalizedString)
            .filter { !$0.isEmpty }
            .sorted()
    }

    private var iso8601DateOnly: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private func persistPlanCacheIfNeeded(_ plan: PersonalizedRecoveryPlan) async {
        let payload = RecoveryPlanCacheUpsert(
            user_id: plan.userId.uuidString.lowercased(),
            procedure_id: plan.procedureId,
            procedure_name: plan.procedureName,
            procedure_date: plan.procedureDate,
            plan_version: plan.planVersion,
            input_hash: plan.inputHash,
            generated_at: plan.generatedAt,
            current_phase_id: plan.currentPhase.id,
            current_phase_title: plan.currentPhase.title,
            current_phase_status: plan.currentPhase.status.rawValue,
            current_phase_summary: plan.currentPhase.summary,
            current_phase_focus_areas: plan.currentPhase.focusAreas,
            personalization_summary: plan.personalizationSummary,
            plan_json: plan,
            source: "app_generated"
        )

        do {
            try await supabase.database
                .from("user_recovery_plan_cache")
                .upsert(payload, onConflict: "user_id,input_hash")
                .execute()
        } catch {
            print("RecoveryPlanService cache persistence failed: \(error)")
        }
    }
}

private struct ResolvedRecoveryPlanContext {
    let procedureName: String
    let procedureId: String?
    let procedureDate: Date
    let timeline: RecoveryPlanTimeline
    let input: RecoveryPlanInput
}

private struct ProcedureContext {
    let id: String?
    let name: String?
    let date: Date?
}

private struct RecoveryPlanHashPayload: Encodable {
    let procedureName: String
    let procedureDate: String
    let daysSinceProcedure: Int
    let currentWeek: Int
    let currentPhaseTitle: String
    let procedureFamily: String
    let gender: String?
    let ageRange: String?
    let raceEthnicity: String?
    let aestheticGoals: [String]
    let bodyAreas: [String]
    let proceduresOfInterest: [String]
    let previousProcedures: [String]
    let healthFlags: [String]
    let latestJournalSignals: RecoveryPlanHashJournalSignals?
}

private struct RecoveryPlanHashJournalSignals: Encodable {
    let entryCount: Int
    let latestPainLevel: Int?
    let latestSwellingLevel: Int?
    let latestBruisingLevel: Int?
    let latestRednessLevel: Int?
    let weeklySummaryHeadline: String?
    let activeAlerts: [String]
}

private struct RecoveryPlanCacheUpsert: Encodable {
    let user_id: String
    let procedure_id: String?
    let procedure_name: String
    let procedure_date: Date
    let plan_version: Int
    let input_hash: String
    let generated_at: Date
    let current_phase_id: String
    let current_phase_title: String
    let current_phase_status: String
    let current_phase_summary: String
    let current_phase_focus_areas: [String]
    let personalization_summary: [String]
    let plan_json: PersonalizedRecoveryPlan
    let source: String
}
