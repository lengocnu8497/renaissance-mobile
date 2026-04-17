//
//  PostLoginHomeView.swift
//  Renaissance Mobile
//

import SwiftUI
import StoreKit

private enum HomeUI {
    static let shell = Color(hex: "#EEF1E8")
    static let background = Color(hex: "#F6F7F2")
    static let surface = Color(hex: "#FBFCF8")
    static let card = Color(hex: "#EDF1E8")
    static let cardStrong = Color(hex: "#E1E7DA")
    static let line = Color(hex: "#CFD6C7")
    static let text = Color(hex: "#1F261D")
    static let muted = Color(hex: "#687064")
    static let primary = Color(hex: "#516048")
    static let primaryInk = Color(hex: "#314030")
    static let primarySoft = Color(hex: "#D9E3CE")
    static let rose = Color(hex: "#B07B7A")
    static let roseSoft = Color(hex: "#F1DDDA")
    static let alert = Color(hex: "#A85555")
    static let success = Color(hex: "#4D7A58")
    static let shadow = Color(hex: "#5A6750").opacity(0.10)
}

private enum HomeMode {
    case recovery
    case research
}

private enum HomeProcedureImageResolver {
    static func image(for procedure: Procedure) -> UIImage? {
        let slug = slug(for: procedure.name)
        let candidateAssetNames = [
            slug,
            "procedure-\(slug)",
            "\(slug)-hero",
            "\(slug)_hero"
        ]

        for name in candidateAssetNames {
            if let image = UIImage(named: name) {
                return image
            }
        }

        return nil
    }

    private static func slug(for name: String) -> String {
        let normalized = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " "))
        let cleanedScalars = normalized.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : " "
        }

        return String(cleanedScalars)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .joined(separator: "_")
            .lowercased()
    }
}

struct PostLoginHomeView: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @State private var firstName = ""
    @State private var journalViewModel = JournalViewModel()
    @State private var proceduresViewModel = ProceduresViewModel()
    @State private var researchViewModel = ResearchViewModel()
    @State private var isSubscribed = false
    @State private var selectedMode: HomeMode = .recovery
    @State private var selectedProcedure: Procedure?
    @State private var selectedSavedForDetail: SavedProcedure?
    @State private var recentSessions: [ChatConversation] = []
    @State private var loadingRecentSessions = false
    @State private var showExploreSheet = false
    @State private var didAttemptValueMomentReview = false
    @State private var showPaywall = false
    @State private var showRecoveryPlan = false

    var onNavigateToChat: ((String) -> Void)?
    var onNavigateToJournal: (() -> Void)?

    private let userProfileService = UserProfileService(supabase: supabase)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    headerSection
                    modeSwitch
                    modeContent
                }
                .padding(.horizontal, 18)
                .padding(.top, 46)
                .padding(.bottom, 120)
            }
            .background(HomeUI.shell.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedProcedure) { procedure in
                ProcedureDetailView(
                    procedure: procedure,
                    allProcedures: proceduresViewModel.procedures,
                    onNavigateToChat: { msg, _ in
                        onNavigateToChat?(msg)
                    },
                    onSaveProcedure: { [researchViewModel] proc in
                        Task { await researchViewModel.toggleSave(proc) }
                    },
                    isSaved: researchViewModel.isSaved(procedure.id),
                    isSavedProcedure: { [researchViewModel] in researchViewModel.isSaved($0) }
                )
            }
            .navigationDestination(item: $selectedSavedForDetail) { saved in
                if let proc = researchViewModel.procedure(for: saved) {
                    SavedProcedureDetailView(
                        saved: saved,
                        procedure: proc,
                        viewModel: researchViewModel,
                        onNavigateToChat: { msg, _ in
                            onNavigateToChat?(msg)
                        },
                        onReopenConversation: nil
                    )
                }
            }
            .navigationDestination(isPresented: $showRecoveryPlan) {
                RecoveryPlanView(
                    journalViewModel: journalViewModel,
                    isLocked: !isSubscribed,
                    onUpgrade: {
                        showRecoveryPlan = false
                        showPaywall = true
                    }
                )
            }
            .sheet(isPresented: $showExploreSheet) {
                NavigationStack {
                    ProceduresListView(
                        initialSavedIds: Set(researchViewModel.savedProcedures.map { $0.procedureId }),
                        researchViewModel: researchViewModel,
                        onBackButtonTapped: { showExploreSheet = false },
                        onNavigateToChat: { msg, _ in
                            showExploreSheet = false
                            onNavigateToChat?(msg)
                        }
                    )
                }
            }
            .sheet(isPresented: $showPaywall) {
                QuotaExceededView(
                    onDismiss: { showPaywall = false },
                    onSubscribed: {
                        showPaywall = false
                        Task {
                            await loadHomeData()
                            requestValueMomentReviewIfNeeded()
                        }
                    }
                )
            }
            .onChange(of: showExploreSheet) { _, isPresented in
                guard !isPresented else { return }
                Task {
                    await researchViewModel.load()
                    await loadRecentSessions()
                }
            }
            .task {
                await subscriptionStore.prepare()
                await loadHomeData()
                requestValueMomentReviewIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
                Task {
                    await loadHomeData()
                    requestValueMomentReviewIfNeeded()
                }
            }
        }
    }

    // MARK: - Data

    private func loadHomeData() async {
        do {
            let profile = try await userProfileService.getUserProfile()
            if let fullName = profile.fullName, !fullName.isEmpty {
                firstName = fullName.components(separatedBy: " ").first ?? fullName
            }

            let subscribed = subscriptionStore.hasActiveSubscription
                || SubscriptionAccessEvaluator.hasBackendPremiumAccess(profile)
            isSubscribed = subscribed
            journalViewModel.insightsEnabled = subscribed
            if !subscribed {
                journalViewModel.clearAIOutputs()
            }
        } catch {
            print("Failed to load user profile: \(error)")
            isSubscribed = false
            journalViewModel.insightsEnabled = false
            journalViewModel.clearAIOutputs()
        }

        await journalViewModel.load()
        if OnboardingStore.hasCompleted {
            await OnboardingStore.applyIfNeeded(to: journalViewModel)
        }
        await proceduresViewModel.fetchProcedures()
        await researchViewModel.load()
        await loadRecentSessions()

        guard isSubscribed else { return }
        journalViewModel.loadCachedWeeklySummaries()
        await journalViewModel.loadRemoteWeeklySummaries()
    }

    private func requestValueMomentReviewIfNeeded() {
        guard !didAttemptValueMomentReview else { return }
        guard ReviewPromptStore.shouldRequestAutomaticReview else { return }
        guard isSubscribed else { return }
        guard journalViewModel.entries.count >= 3 else { return }
        guard latestPrimaryWeeklySummary != nil else { return }

        didAttemptValueMomentReview = true
        Task { @MainActor in
            let outcome = await ReviewRequestHelper.requestWhenReady()
            guard outcome == .requested else {
                didAttemptValueMomentReview = false
                return
            }
            ReviewPromptStore.markAutomaticReviewRequested()
        }
    }

    private var primaryProcedureName: String {
        journalViewModel.primaryProcedureName ?? "Recovery"
    }

    private var firstNameDisplay: String {
        firstName.isEmpty ? "there" : firstName
    }

    private var latestEntry: JournalEntry? {
        journalViewModel.entries.max(by: { $0.entryDateAsDate < $1.entryDateAsDate })
    }

    private var latestPrimaryWeeklySummary: WeeklySummary? {
        guard let procedureId = journalViewModel.primaryProcedureId else { return nil }
        return journalViewModel.weeklySummaries.values
            .filter { $0.procedureId == procedureId }
            .sorted { lhs, rhs in
                if lhs.weekNumber == rhs.weekNumber {
                    return lhs.generatedAt > rhs.generatedAt
                }
                return lhs.weekNumber > rhs.weekNumber
            }
            .first
    }

    private var resolvedWeeklyPreview: JournalWeeklyReportPreview {
        if !isSubscribed {
            return JournalWeeklyReportPreview(
                weekNumber: 1,
                title: "Premium feature: Weekly AI reports.",
                subtitle: "Subscribe to unlock automated weekly reports, AI insights, and personalized recovery guidance.",
                statusLabel: "Premium feature",
                progress: 0,
                actionTitle: "Unlock Premium",
                summary: nil
            )
        }

        if let preview = journalViewModel.weeklyReportPreview {
            return preview
        }

        let hasEntries = !journalViewModel.entries.isEmpty
        return JournalWeeklyReportPreview(
            weekNumber: 1,
            title: hasEntries ? "Week 1 is almost ready." : "Week 1 is getting started.",
            subtitle: hasEntries
                ? "Add one more detailed log and your weekly report will auto-fill with trends and insights."
                : "Keep logging daily and your weekly report will auto-fill with trends and insights.",
            statusLabel: hasEntries ? "Building" : "Starting",
            progress: hasEntries ? max(68, journalViewModel.weeklyReportProgress) : 18,
            actionTitle: hasEntries ? "See preview" : "Keep logging",
            summary: nil
        )
    }

    private var activeWeeklyCheckIns: [WeeklyCheckIn] {
        guard let procedureId = journalViewModel.primaryProcedureId ?? journalViewModel.bootstrappedProcedureId else {
            return []
        }
        return journalViewModel.checkIns(for: procedureId)
    }

    private var hasHomeAttentionState: Bool {
        let hasPendingWeekly = activeWeeklyCheckIns.contains { !$0.isCompleted && $0.scheduledDate <= Date() }
        return hasPendingWeekly || !journalViewModel.primarySmartAlerts.isEmpty
    }

    private var proceduresToResearch: [Procedure] {
        let savedIds = Set(researchViewModel.savedProcedures.map(\.procedureId))
        let prioritizedSaved = researchViewModel.shortlistCards.map(\.procedure)
        let additional = proceduresViewModel.procedures
            .filter { !savedIds.contains($0.id) }
            .sorted { $0.sortOrder < $1.sortOrder }
        return Array((prioritizedSaved + additional).prefix(6))
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hello, \(firstNameDisplay)")
                    .font(.system(size: 29, weight: .heavy, design: .rounded))
                    .foregroundColor(HomeUI.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer()

            bellStatusButton
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 8) {
            modeButton(title: "Recovery", mode: .recovery)
            modeButton(title: "Research", mode: .research)
        }
        .padding(8)
        .background(HomeUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var modeContent: some View {
        switch selectedMode {
        case .recovery:
            recoveryModeContent
        case .research:
            researchModeContent
        }
    }

    private func modeButton(title: String, mode: HomeMode) -> some View {
        let isSelected = selectedMode == mode
        return Button {
            selectedMode = mode
        } label: {
            Text(title)
                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                .foregroundColor(isSelected ? .white : HomeUI.primaryInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(isSelected ? HomeUI.primary : .white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelected ? Color.clear : Color.black.opacity(0.05), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var recoveryModeContent: some View {
        Group {
            JournalStreakStrip(
                streak: journalViewModel.streak,
                dayNumber: journalViewModel.heroData?.dayNumber ?? 0,
                procedureName: journalViewModel.primaryProcedureName
            )

            JournalTodayCard(
                latestEntry: journalViewModel.latestEntry,
                procedureName: journalViewModel.primaryProcedureName,
                onLogToday: { journalViewModel.tapAddEntry(for: journalViewModel.primaryProcedureName) }
            )

            JournalRecoveryScoreCard(score: journalViewModel.primaryRecoveryScore)

            askRenaRecoveryCard

            HStack(alignment: .top, spacing: 12) {
                JournalPainTrendCard(painSeries: journalViewModel.primaryPainSeries)
                JournalTodaySignalsCard(
                    pain: journalViewModel.latestPainLevel,
                    swelling: journalViewModel.latestSwellingLevel,
                    bruising: journalViewModel.latestBruisingLevel
                )
            }

            if let alert = journalViewModel.journalAlert {
                JournalAlertCard(alert: alert)
            }

            recoveryRoadmapCard

            JournalWeeklyReportCard(
                preview: resolvedWeeklyPreview,
                onOpenReport: {
                    guard isSubscribed else {
                        showPaywall = true
                        return
                    }
                    onNavigateToJournal?()
                }
            )

            recentJournalSection

            JournalPhotoReelSection(
                entries: journalViewModel.photoReelEntries(),
                onOpenGallery: { onNavigateToJournal?() }
            )
        }
    }

    private var recoveryRoadmapCard: some View {
        ModernHomeCard(background: .white, padding: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HomeEyebrow(isSubscribed ? "Recovery roadmap" : "Premium feature", color: HomeUI.rose)

                    Text(isSubscribed ? "See your recovery roadmap" : "Your next weeks are already mapped")
                        .font(.custom("Manrope", size: 23))
                        .fontWeight(.bold)
                        .foregroundColor(HomeUI.primaryInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(
                        isSubscribed
                        ? "Open your personalized week-by-week roadmap, watch-fors, and provider prompts."
                        : "Preview the roadmap built from your procedure and timing, then unlock the full phase-by-phase plan."
                    )
                    .font(.custom("Outfit-Regular", size: 13.5))
                    .foregroundColor(HomeUI.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        roadmapChip("Starts from today")
                        roadmapChip(isSubscribed ? "Unlocked" : "Locked ahead")
                    }
                }

                Spacer(minLength: 0)

                Button {
                    if isSubscribed {
                        showRecoveryPlan = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isSubscribed ? HomeUI.primarySoft : HomeUI.roseSoft)
                            .frame(width: 64, height: 64)

                        Image(systemName: isSubscribed ? "map.fill" : "lock.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isSubscribed ? HomeUI.primary : HomeUI.rose)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showRecoveryPlan = true
        }
    }

    private func roadmapChip(_ title: String) -> some View {
        Text(title)
            .font(.custom("PlusJakartaSans-SemiBold", size: 10))
            .foregroundColor(HomeUI.primaryInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(HomeUI.card)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
    }

    private var researchModeContent: some View {
        Group {
            researchHeroSection
            askRenaResearchCard
            proceduresToResearchSection
            shortlistShelfSection
            exploreNextSection
            savedResearchSection
            consultationPrepSection
            researchSessionsSection
        }
    }

    private var bellStatusButton: some View {
        Button {
            onNavigateToJournal?()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(HomeUI.primary)
                    .frame(width: 44, height: 44)
                    .background(HomeUI.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: HomeUI.shadow, radius: 10, x: 0, y: 4)

                if hasHomeAttentionState {
                    Circle()
                        .fill(HomeUI.rose)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var researchHeroSection: some View {
        ModernHomeCard(background: .white, padding: 20) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HomeEyebrow("Research home", color: HomeUI.muted)
                    Text("Organize what to explore before you book anything.")
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                        .foregroundColor(HomeUI.primaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Research mode keeps procedures, comparisons, and consult questions in one focused place.")
                        .font(.custom("Outfit-Regular", size: 14))
                        .foregroundColor(HomeUI.muted)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(spacing: 2) {
                    Text("THIS WEEK")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                        .tracking(1.8)
                        .foregroundColor(HomeUI.muted)
                    Text("\(researchViewModel.shortlistCards.count) saved")
                        .font(.custom("Manrope", size: 22))
                        .fontWeight(.bold)
                        .foregroundColor(HomeUI.primary)
                }
                .frame(width: 108)
                .padding(.vertical, 14)
                .background(HomeUI.card)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private var proceduresToResearchSection: some View {
        ModernHomeCard(background: HomeUI.card, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HomeEyebrow("Procedures to research", color: HomeUI.muted)
                        Text("Start with what fits your goals")
                            .font(.custom("Manrope", size: 24))
                            .fontWeight(.bold)
                            .foregroundColor(HomeUI.primaryInk)
                    }
                    Spacer()
                    Button {
                        showExploreSheet = true
                    } label: {
                        Text("Browse all")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                            .foregroundColor(HomeUI.primaryInk)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(proceduresToResearch, id: \.id) { procedure in
                            Button {
                                selectedProcedure = procedure
                            } label: {
                                procedureResearchCard(procedure)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func procedureResearchCard(_ procedure: Procedure) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let image = HomeProcedureImageResolver.image(for: procedure) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [HomeUI.primarySoft.opacity(0.96), Color.white.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(HomeUI.primary.opacity(0.75))
                    )
                }
            }
            .frame(width: 176, height: 214)
            .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.02),
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.64),
                    Color.black.opacity(0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(procedure.name)
                    .font(.custom("Manrope", size: 18))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(procedure.recoveryDurationLabel.isEmpty ? (procedure.isSurgical ? "Surgical" : "Non-surgical") : procedure.recoveryDurationLabel)
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundColor(.white.opacity(0.84))
                    .lineLimit(1)
            }
            .padding(16)
        }
        .frame(width: 176, height: 214, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: HomeUI.shadow, radius: 10, x: 0, y: 3)
    }

    private var askRenaRecoveryCard: some View {
        Button {
            onNavigateToChat?("What is normal for swelling in week 2?")
        } label: {
            askRenaCardContent(
                title: "Ask Rena",
                body: "What is normal today?"
            )
        }
        .buttonStyle(.plain)
    }

    private var askRenaResearchCard: some View {
        Button {
            onNavigateToChat?("Help me compare procedures and figure out what to research first.")
        } label: {
            askRenaCardContent(
                title: "Ask Rena",
                body: "What should I ask in a consultation?"
            )
        }
        .buttonStyle(.plain)
    }

    private func askRenaCardContent(title: String, body: String) -> some View {
        ModernHomeCard(background: HomeUI.surface, padding: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(HomeUI.primarySoft)
                        .frame(width: 48, height: 48)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 18))
                        .foregroundColor(HomeUI.primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.custom("Outfit-SemiBold", size: 15))
                        .foregroundColor(HomeUI.text)
                    Text(body)
                        .font(.custom("Outfit-Regular", size: 12.5))
                        .foregroundColor(HomeUI.muted)
                }

                Spacer()

                CircleArrow()
            }
        }
    }

    @ViewBuilder
    private var recentJournalSection: some View {
        if let entry = latestEntry {
            ModernHomeCard(background: HomeUI.surface, padding: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HomeEyebrow("Recent Journal", color: HomeUI.muted)
                            Text(entry.entryDateAsDate.formatted(.dateTime.weekday(.wide)))
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundColor(HomeUI.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                        Spacer()
                        Button {
                            onNavigateToJournal?()
                        } label: {
                            Text("View all")
                                .font(.custom("Outfit-SemiBold", size: 13))
                                .foregroundColor(HomeUI.primary)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.procedureName)
                                    .font(.custom("Outfit-SemiBold", size: 15))
                                    .foregroundColor(HomeUI.text)
                                Text("Day \(entry.dayNumber) • \(entry.entryDateAsDate.formatted(date: .omitted, time: .shortened))")
                                    .font(.custom("Outfit-Regular", size: 12))
                                    .foregroundColor(HomeUI.muted)
                            }
                            Spacer()
                            GradientChip(title: "raw daily log")
                        }

                        Text(entry.notes?.isEmpty == false ? entry.notes! : "Add notes to your next daily check-in so Rena can turn them into sharper weekly insights.")
                            .font(.custom("Outfit-Regular", size: 14))
                            .foregroundColor(HomeUI.text.opacity(0.72))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(17)
                    .background(HomeUI.card)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
        }
    }

    private var shortlistShelfSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HomeEyebrow("Your shortlist", color: HomeUI.muted)
                    Text("Saved procedures")
                        .font(.custom("Manrope", size: 24))
                        .fontWeight(.bold)
                        .foregroundColor(HomeUI.primaryInk)
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if researchViewModel.shortlistCards.isEmpty {
                        researchEmptyShortlistCard(
                            title: "Save your first procedure",
                            subtitle: "Your shortlist lives here. Save 1-2 procedures you're considering so you can compare recovery, questions, and sessions in one place.",
                            accent: .white
                        )
                        researchEmptyShortlistCard(
                            title: "Build your consultation prep",
                            subtitle: "Once saved, each procedure gets its own notes, questions, and a direct path to Ask Rena.",
                            accent: HomeUI.card
                        )
                    } else {
                        ForEach(researchViewModel.shortlistCards) { card in
                            Button {
                                selectedSavedForDetail = researchViewModel.savedEntry(for: card.procedure.id)
                            } label: {
                                ZStack(alignment: .bottomLeading) {
                                    Group {
                                        if let image = HomeProcedureImageResolver.image(for: card.procedure) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            LinearGradient(
                                                colors: [HomeUI.primarySoft.opacity(0.92), HomeUI.cardStrong.opacity(0.96)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        }
                                    }
                                    .frame(width: 210, height: 164)
                                    .clipped()

                                    LinearGradient(
                                        colors: [
                                            Color.black.opacity(0.02),
                                            Color.black.opacity(0.12),
                                            Color.black.opacity(0.64),
                                            Color.black.opacity(0.82)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )

                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(card.procedure.category.uppercased())
                                            .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                                            .tracking(1.8)
                                            .foregroundColor(.white.opacity(0.82))
                                        Text(card.procedure.name)
                                            .font(.custom("Manrope", size: 21))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .lineLimit(2)
                                        HStack(spacing: 6) {
                                            if !card.procedure.recoveryDurationLabel.isEmpty {
                                                researchPill(card.procedure.recoveryDurationLabel, tint: Color.black.opacity(0.28), textColor: .white)
                                            }
                                            if card.questionCount > 0 {
                                                researchPill("\(card.questionCount) questions", tint: HomeUI.roseSoft.opacity(0.92), textColor: HomeUI.primaryInk)
                                            }
                                        }
                                    }
                                    .padding(18)
                                }
                                .frame(width: 210)
                                .frame(minHeight: 164, alignment: .leading)
                                .cornerRadius(26)
                                .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.black.opacity(0.05), lineWidth: 1))
                                .shadow(color: HomeUI.shadow, radius: 10, x: 0, y: 3)
                                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var exploreNextSection: some View {
        ModernHomeCard(background: HomeUI.card, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HomeEyebrow("Explore next", color: HomeUI.muted)
                    Spacer()
                    Image(systemName: "safari")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(HomeUI.primary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(researchExploreSuggestions, id: \.self) { suggestion in
                            Button {
                                showExploreSheet = true
                            } label: {
                                Text(suggestion)
                                    .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                                    .foregroundColor(HomeUI.primaryInk)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    private var savedResearchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeEyebrow("Saved research", color: HomeUI.muted)

            if researchViewModel.shortlistCards.isEmpty {
                ModernHomeCard(background: HomeUI.surface, padding: 18) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Save a procedure to unlock details")
                            .font(.custom("Manrope", size: 24))
                            .fontWeight(.bold)
                            .foregroundColor(HomeUI.text)

                        HStack(spacing: 8) {
                            researchPill("Recovery timeline", tint: .white, textColor: HomeUI.muted)
                            researchPill("Questions", tint: HomeUI.roseSoft, textColor: HomeUI.primaryInk)
                            researchPill("Ask Rena", tint: HomeUI.primarySoft, textColor: HomeUI.primaryInk)
                        }

                        Text("Saved procedures become your research workspace. You’ll see recovery tags, cost context, your own questions, and quick actions to open details or continue with Rena.")
                            .font(.custom("PlusJakartaSans-Regular", size: 14))
                            .foregroundColor(HomeUI.text.opacity(0.74))
                            .lineSpacing(3)

                        HStack(spacing: 12) {
                            Button {
                                showExploreSheet = true
                            } label: {
                                Text("Explore procedures")
                                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(HomeUI.primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                onNavigateToChat?("Help me compare procedures and figure out what to research first.")
                            } label: {
                                Text("Ask Rena")
                                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                    .foregroundColor(HomeUI.primaryInk)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                ForEach(researchViewModel.shortlistCards) { card in
                    researchSavedCard(card)
                }
            }
        }
    }

    private var consultationPrepSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HomeEyebrow("Consultation prep", color: HomeUI.muted)
                    Text("Questions to bring")
                        .font(.custom("Manrope", size: 24))
                        .fontWeight(.bold)
                        .foregroundColor(HomeUI.text)
                }
                Spacer()
                Image(systemName: "text.bubble")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(HomeUI.primary)
            }

            ModernHomeCard(background: .white, padding: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    if let featured = featuredQuestionCard {
                        Text(featured.procedure.name)
                            .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                            .foregroundColor(HomeUI.primaryInk)

                        ForEach(featured.questions, id: \.self) { question in
                            Text(question)
                                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                .foregroundColor(HomeUI.primaryInk)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(HomeUI.card)
                                .cornerRadius(22)
                        }
                    } else {
                        Text("Start collecting questions before your consult.")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                            .foregroundColor(HomeUI.primaryInk)

                        ForEach(exampleConsultationQuestions, id: \.self) { question in
                            Text(question)
                                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                .foregroundColor(HomeUI.primaryInk)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(HomeUI.card)
                                .cornerRadius(22)
                        }
                    }
                }
            }
        }
    }

    private var researchSessionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HomeEyebrow("Research sessions", color: HomeUI.muted)
                    Text("Continue where you left off")
                        .font(.custom("Manrope", size: 24))
                        .fontWeight(.bold)
                        .foregroundColor(HomeUI.text)
                }
                Spacer()
                if loadingRecentSessions {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(HomeUI.primary)
                } else {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(HomeUI.primary)
                }
            }

            ModernHomeCard(background: HomeUI.cardStrong, padding: 18) {
                if recentSessions.isEmpty && !loadingRecentSessions {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your future research chats will live here.")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                            .foregroundColor(HomeUI.primaryInk)
                        Text("Ask Rena about a procedure, then come back here to quickly resume your research without starting over.")
                            .font(.custom("PlusJakartaSans-Regular", size: 13))
                            .foregroundColor(HomeUI.muted)
                            .lineSpacing(3)
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(recentSessions.prefix(3)) { conversation in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(conversation.title ?? "Research session")
                                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                        .foregroundColor(HomeUI.text)
                                        .lineLimit(2)
                                    Text(sessionSubtitle(for: conversation))
                                        .font(.custom("PlusJakartaSans-Regular", size: 11))
                                        .foregroundColor(HomeUI.muted)
                                }
                                Spacer()
                                Text("Resume")
                                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                                    .foregroundColor(HomeUI.primaryInk)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(HomeUI.card)
                                    .clipShape(Capsule())
                            }
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(22)
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.black.opacity(0.05), lineWidth: 1))
                        }
                    }
                }
            }
        }
    }

    private func researchEmptyShortlistCard(title: String, subtitle: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EXAMPLE")
                .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                .tracking(1.8)
                .foregroundColor(HomeUI.muted)
            Text(title)
                .font(.custom("Manrope", size: 21))
                .fontWeight(.bold)
                .foregroundColor(HomeUI.text)
                .lineLimit(2)
            Text(subtitle)
                .font(.custom("PlusJakartaSans-Regular", size: 13))
                .foregroundColor(HomeUI.text.opacity(0.72))
                .lineSpacing(3)
            HStack(spacing: 6) {
                researchPill("Save", tint: .white, textColor: HomeUI.muted)
                researchPill("Questions", tint: HomeUI.roseSoft, textColor: HomeUI.primaryInk)
            }
        }
        .frame(width: 210)
        .frame(minHeight: 144, alignment: .leading)
        .padding(18)
        .background(accent)
        .cornerRadius(26)
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.black.opacity(0.05), lineWidth: 1))
        .shadow(color: HomeUI.shadow, radius: 10, x: 0, y: 3)
    }

    private func researchSavedCard(_ card: SavedProcedureCardModel) -> some View {
        ModernHomeCard(background: HomeUI.surface, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(card.procedure.category.uppercased())
                            .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                            .tracking(1.8)
                            .foregroundColor(HomeUI.muted)
                        Text(card.procedure.name)
                            .font(.custom("Manrope", size: 25))
                            .fontWeight(.bold)
                            .foregroundColor(HomeUI.text)
                    }
                    Spacer()
                    Text("saved")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                        .foregroundColor(HomeUI.primaryInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    if !card.procedure.recoveryDurationLabel.isEmpty {
                        researchPill(card.procedure.recoveryDurationLabel, tint: .white, textColor: HomeUI.muted)
                    }
                    researchPill(
                        card.procedure.isSurgical ? "Surgical" : "Non-Surgical",
                        tint: card.procedure.isSurgical ? HomeUI.roseSoft : HomeUI.primarySoft,
                        textColor: HomeUI.primaryInk
                    )
                    if let cost = card.procedure.costRangeDisplay {
                        researchPill(cost, tint: HomeUI.primarySoft, textColor: HomeUI.primaryInk)
                    }
                }

                Text(card.procedure.description)
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .foregroundColor(HomeUI.text.opacity(0.74))
                    .lineLimit(3)
                    .lineSpacing(4)

                HStack(spacing: 10) {
                    researchMetricTile("Questions", "\(card.questionCount)", "saved")
                    researchMetricTile("Sessions", "\(card.linkedSessionCount)", card.linkedSessionCount > 0 ? "active" : "none yet")
                }

                HStack(spacing: 12) {
                    Button {
                        selectedSavedForDetail = researchViewModel.savedEntry(for: card.procedure.id)
                    } label: {
                        Text("Open details")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(HomeUI.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onNavigateToChat?("I'm researching \(card.procedure.name) and I have some questions about it.")
                    } label: {
                        Text("Ask Rena")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                            .foregroundColor(HomeUI.primaryInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func researchPill(_ text: String, tint: Color, textColor: Color) -> some View {
        Text(text)
            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
            .foregroundColor(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint)
            .clipShape(Capsule())
    }

    private func researchMetricTile(_ label: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                .tracking(1.4)
                .foregroundColor(HomeUI.muted)
                .textCase(.uppercase)
            Text(value)
                .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                .foregroundColor(HomeUI.primaryInk)
            Text(detail)
                .font(.custom("PlusJakartaSans-Regular", size: 11))
                .foregroundColor(HomeUI.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Color.white)
        .cornerRadius(22)
    }

    private func shortlistSurface(for id: UUID) -> Color {
        guard let idx = researchViewModel.shortlistCards.firstIndex(where: { $0.id == id }) else { return .white }
        switch idx % 3 {
        case 1: return HomeUI.card
        case 2: return HomeUI.cardStrong
        default: return .white
        }
    }

    private var featuredQuestionCard: (procedure: Procedure, questions: [String])? {
        for saved in researchViewModel.savedProcedures {
            guard !saved.questions.isEmpty, let procedure = researchViewModel.procedure(for: saved) else { continue }
            return (procedure, Array(saved.questions.prefix(3)))
        }
        return nil
    }

    private var exampleConsultationQuestions: [String] {
        [
            "What changes are realistic for my features and anatomy?",
            "How long will swelling or downtime affect what I see?",
            "Can you walk me through before-and-afters similar to my case?"
        ]
    }

    private var researchExploreSuggestions: [String] {
        if researchViewModel.shortlistCards.isEmpty {
            return ["Natural-result rhinoplasty", "Mini facelift recovery", "Lower bleph cost"]
        }
        return researchViewModel.exploreSuggestions
    }

    private func sessionSubtitle(for conversation: ChatConversation) -> String {
        "\(RelativeDateTimeFormatter().localizedString(for: conversation.updatedAt, relativeTo: Date()).capitalized) • saved research"
    }

    private func loadRecentSessions() async {
        loadingRecentSessions = true
        defer { loadingRecentSessions = false }
        let conversationIds = Array(Set(researchViewModel.savedProcedures.flatMap(\.conversationIds)))
        recentSessions = await researchViewModel.fetchConversations(for: conversationIds)
            .sorted { $0.updatedAt > $1.updatedAt }
    }
}

private struct HomeEyebrow: View {
    let title: String
    let color: Color

    init(_ title: String, color: Color) {
        self.title = title
        self.color = color
    }

    var body: some View {
        Text(title)
            .font(.custom("Outfit-SemiBold", size: 10.5))
            .tracking(2.2)
            .foregroundColor(color)
            .textCase(.uppercase)
    }
}

private struct GradientChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.custom("Outfit-SemiBold", size: 11))
            .foregroundColor(HomeUI.primaryInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                LinearGradient(
                    colors: [HomeUI.primarySoft, HomeUI.roseSoft],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
    }
}

private struct CircleArrow: View {
    var body: some View {
        Circle()
            .fill(HomeUI.primarySoft)
            .frame(width: 30, height: 30)
            .overlay(
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HomeUI.primary)
            )
    }
}

private struct ModernHomeCard<Content: View>: View {
    let background: Color
    let padding: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: HomeUI.shadow, radius: 18, x: 0, y: 8)
    }
}

#Preview {
    PostLoginHomeView()
}
