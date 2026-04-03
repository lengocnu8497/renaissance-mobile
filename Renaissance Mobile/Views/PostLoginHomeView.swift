//
//  PostLoginHomeView.swift
//  Renaissance Mobile
//

import SwiftUI

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

struct PostLoginHomeView: View {
    @State private var firstName = ""
    @State private var journalViewModel = JournalViewModel()
    @State private var isSubscribed = false

    var onNavigateToChat: ((String) -> Void)?
    var onNavigateToJournal: (() -> Void)?

    private let userProfileService = UserProfileService(supabase: supabase)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    headerSection
                    heroSection
                    askRenaCard
                    weeklyReportSection
                    progressGridSection
                    smartAlertSection
                    lowerGridSection
                    recentJournalSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 52)
                .padding(.bottom, 120)
            }
            .background(HomeUI.shell.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await loadHomeData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .subscriptionLinked)) { _ in
                Task { await loadHomeData() }
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

            let subscribed = profile.billingPlan == .silver
                || profile.billingPlan == .gold
                || profile.billingPlan == .annual
            isSubscribed = subscribed
            journalViewModel.insightsEnabled = subscribed
        } catch {
            print("Failed to load user profile: \(error)")
        }

        await journalViewModel.load()
        await OnboardingStore.applyIfNeeded(to: journalViewModel)

        guard isSubscribed else { return }
        journalViewModel.loadCachedWeeklySummaries()
        await journalViewModel.loadRemoteWeeklySummaries()
    }

    private var primaryProcedureName: String {
        journalViewModel.primaryProcedureName ?? "Recovery"
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

    private var heroTitle: String {
        guard let score = journalViewModel.primaryRecoveryScore else {
            return "Start your recovery log."
        }
        switch score.symptomTrend {
        case .improving:
            return "Your healing looks on track."
        case .stable:
            return "Your recovery looks steady."
        case .concerning:
            return "Your healing needs a closer look."
        }
    }

    private var heroSupportText: String {
        journalViewModel.hasLoggedToday
            ? "Today's check-in is in. Keep the streak going and let your weekly report keep building."
            : "Stay consistent today and keep your weekly report building itself."
    }

    private var painTrendLabel: String {
        journalViewModel.primaryRecoveryScore?.symptomTrend.label ?? "No data"
    }

    private var consistencyLabel: String {
        if let score = journalViewModel.primaryRecoveryScore {
            return "\(score.consistencyRate)%"
        }
        return "Start"
    }

    private var chartValues: [Int] {
        let values = Array(journalViewModel.primaryPainSeries.suffix(5))
        return values.isEmpty ? [0, 0, 0, 0, 0] : values
    }

    private var chartDayLabels: [String] {
        let values = Array(journalViewModel.primaryProcedureEntries.suffix(5))
        if values.isEmpty {
            return ["D1", "D2", "D3", "D4", "D5"]
        }
        return values.map { "D\($0.dayNumber)" }
    }

    private var painTrendPath: String {
        let values = chartValues.filter { $0 > 0 }
        return values.isEmpty ? "No pain logs yet" : values.map(String.init).joined(separator: " → ")
    }

    private var todayMetrics: [(label: String, value: Double, color: Color)] {
        [
            ("Pain", latestEntry?.painLevel ?? 0, HomeUI.success),
            ("Swelling", latestEntry?.swellingLevel ?? 0, HomeUI.rose),
            ("Bruising", latestEntry?.bruisingLevel ?? 0, HomeUI.primary)
        ]
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hello, \(firstName.isEmpty ? "there" : firstName)")
                    .font(.system(size: 31, weight: .heavy, design: .rounded))
                    .foregroundColor(HomeUI.text)
            }

            Spacer()

            bellStatusButton
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

    private var heroSection: some View {
        ModernHomeCard(background: .white, padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        HomeEyebrow(heroEyebrow, color: HomeUI.muted)

                        Text(heroTitle)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(HomeUI.primaryInk)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(-1)

                        Text(heroSupportText)
                            .font(.custom("Outfit-Regular", size: 14.5))
                            .foregroundColor(HomeUI.muted)
                            .lineSpacing(4)
                    }

                    Spacer(minLength: 0)

                    ScoreBadge(title: "Recovery Score", value: scoreDisplay)
                }

                HStack(spacing: 10) {
                    HomeStatCard(title: "Streak", value: "\(journalViewModel.streak) days", background: HomeUI.card)
                    HomeStatCard(title: "Pain trend", value: painTrendLabel, background: HomeUI.card)
                    HomeStatCard(title: "Consistency", value: consistencyLabel, background: HomeUI.card)
                }

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HomeEyebrow("Today's next step", color: HomeUI.muted)
                        Text(journalViewModel.hasLoggedToday ? "You checked in today." : "Complete today's check-in.")
                            .font(.custom("Outfit-SemiBold", size: 15))
                            .foregroundColor(HomeUI.primaryInk)
                    }

                    Spacer()

                    Button {
                        onNavigateToJournal?()
                    } label: {
                        ActionPill(
                            title: journalViewModel.hasLoggedToday ? "Open journal" : "Log today",
                            foreground: HomeUI.primaryInk,
                            background: HomeUI.primarySoft
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(HomeUI.card)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }

    private var heroEyebrow: String {
        if let day = journalViewModel.heroData?.dayNumber {
            return "Day \(day) of recovery"
        }
        return "Begin recovery tracking"
    }

    private var scoreDisplay: String {
        if let score = journalViewModel.primaryRecoveryScore?.score {
            return "\(score)/100"
        }
        return "--"
    }

    private var askRenaCard: some View {
        Button {
            onNavigateToChat?("")
        } label: {
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
                        Text("Ask Rena")
                            .font(.custom("Outfit-SemiBold", size: 15))
                            .foregroundColor(HomeUI.text)
                        Text("What is normal for swelling in week 2?")
                            .font(.custom("Outfit-Regular", size: 12))
                            .foregroundColor(HomeUI.muted)
                    }

                    Spacer()

                    CircleArrow()
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var weeklyReportSection: some View {
        if let summary = latestPrimaryWeeklySummary {
            ModernHomeCard(background: HomeUI.card, padding: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            HomeEyebrow("Week \(summary.weekNumber) Recovery Report", color: HomeUI.muted)
                            Text("Auto-filled from your daily logs")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundColor(HomeUI.primaryInk)
                        }

                        Spacer()

                        StatusChip(title: "New", foreground: .white, background: HomeUI.primary)
                    }

                    HStack(spacing: 10) {
                        SummaryStatusCard(title: "Pain", value: summary.painTrend ?? "No data", tint: HomeUI.success)
                        SummaryStatusCard(title: "Swelling", value: summary.swellingStatus ?? "No data", tint: HomeUI.text)
                        SummaryStatusCard(title: "Bruising", value: summary.bruisingStatus ?? "No data", tint: HomeUI.text)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HomeEyebrow("Recovery Score", color: HomeUI.primary)
                        Text(summary.recoveryScore.map { "This week scored \($0)/100." } ?? summary.observation)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(HomeUI.primaryInk)
                        if let concern = summary.concern {
                            Text(concern)
                                .font(.custom("Outfit-Regular", size: 13))
                                .foregroundColor(HomeUI.muted)
                                .lineSpacing(4)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [HomeUI.primarySoft, HomeUI.roseSoft],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
            }
        } else if !activeWeeklyCheckIns.isEmpty {
            ModernHomeCard(background: HomeUI.card, padding: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    HomeEyebrow("Weekly Recovery Report", color: HomeUI.muted)
                    Text("Keep logging daily and your first auto-filled weekly report will appear here.")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(HomeUI.primaryInk)
                    Text("Daily logs power your trends, recovery score, and alerts.")
                        .font(.custom("Outfit-Regular", size: 13))
                        .foregroundColor(HomeUI.muted)
                }
            }
        }
    }

    private var progressGridSection: some View {
        HStack(alignment: .top, spacing: 14) {
            ModernHomeCard(background: HomeUI.surface, padding: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            HomeEyebrow("Pain Trend", color: HomeUI.muted)
                            Text(painTrendPath)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(HomeUI.primaryInk)
                        }
                        Spacer()
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(HomeUI.primary)
                    }

                    VStack(spacing: 12) {
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(Array(chartValues.enumerated()), id: \.offset) { index, value in
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(index == chartValues.count - 1 ? HomeUI.primary : HomeUI.primary.opacity(0.35))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: barHeight(for: value))
                            }
                        }
                        .frame(height: 112, alignment: .bottom)

                        HStack {
                            ForEach(Array(chartDayLabels.enumerated()), id: \.offset) { _, label in
                                Text(label)
                                    .font(.custom("Outfit-SemiBold", size: 10))
                                    .tracking(1.6)
                                    .foregroundColor(HomeUI.muted)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }

            ModernHomeCard(background: HomeUI.card, padding: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            HomeEyebrow("Check-in Completion", color: HomeUI.muted)
                            Text("\(journalViewModel.streak)-day streak")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(HomeUI.rose)
                        }
                        Spacer()
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20))
                            .foregroundColor(HomeUI.rose)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Habit strength")
                                .font(.custom("Outfit-Regular", size: 12))
                                .foregroundColor(HomeUI.muted)
                            Spacer()
                            Text(consistencyLabel)
                                .font(.custom("Outfit-SemiBold", size: 12))
                                .foregroundColor(HomeUI.muted)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.white)
                                Capsule()
                                    .fill(HomeUI.primary)
                                    .frame(width: geo.size.width * consistencyProgress)
                            }
                        }
                        .frame(height: 12)
                    }
                }
            }
            .frame(width: 154)
        }
    }

    private var consistencyProgress: CGFloat {
        CGFloat(journalViewModel.primaryRecoveryScore?.consistencyRate ?? 0) / 100
    }

    private func barHeight(for value: Int) -> CGFloat {
        guard value > 0 else { return 20 }
        let clamped = max(1, min(10, value))
        return CGFloat(clamped) / 10 * 100
    }

    @ViewBuilder
    private var smartAlertSection: some View {
        if let alert = journalViewModel.primarySmartAlerts.first {
            ModernHomeCard(background: HomeUI.roseSoft, padding: 18) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white)
                            .frame(width: 46, height: 46)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(HomeUI.alert)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HomeEyebrow("Smart Recovery Alert", color: HomeUI.alert)
                        Text(alert.title)
                            .font(.custom("Outfit-SemiBold", size: 17))
                            .foregroundColor(HomeUI.text)
                        Text(alert.message)
                            .font(.custom("Outfit-Regular", size: 14))
                            .foregroundColor(HomeUI.muted)
                            .lineSpacing(5)
                    }
                }
            }
        }
    }

    private var lowerGridSection: some View {
        VStack(spacing: 14) {
            ModernHomeCard(background: HomeUI.card, padding: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HomeEyebrow("Healing Timeline", color: HomeUI.muted)
                            Text("Recovery photos")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(HomeUI.primaryInk)
                        }
                        Spacer()
                        Button {
                            onNavigateToJournal?()
                        } label: {
                            ActionPill(title: "Open journal", foreground: HomeUI.primary, background: HomeUI.surface)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 10) {
                        ForEach(Array(journalViewModel.primaryPhotoTimeline.prefix(3).enumerated()), id: \.element.id) { _, entry in
                            timelineCard(entry: entry)
                        }

                        if journalViewModel.primaryPhotoTimeline.isEmpty {
                            ForEach(["Day 1", "Day 7", "Day 14"], id: \.self) { label in
                                VStack(alignment: .leading, spacing: 10) {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(.white.opacity(0.75))
                                        .frame(height: 92)
                                    Text(label)
                                        .font(.custom("Outfit-SemiBold", size: 12))
                                        .foregroundColor(HomeUI.text)
                                    Text("Add a daily photo")
                                        .font(.custom("Outfit-Regular", size: 11))
                                        .foregroundColor(HomeUI.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(HomeUI.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 14) {
                ModernHomeCard(background: HomeUI.cardStrong, padding: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        HomeEyebrow("Recovery Today", color: HomeUI.muted)

                        VStack(spacing: 12) {
                            ForEach(todayMetrics, id: \.label) { metric in
                                MetricBarRow(metric: metric)
                            }
                        }
                    }
                }

                if !activeWeeklyCheckIns.isEmpty {
                    ModernHomeCard(background: HomeUI.surface, padding: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            HomeEyebrow("Recovery Plan", color: HomeUI.muted)

                            Text("\(activeWeeklyCheckIns.filter(\.isCompleted).count) of \(activeWeeklyCheckIns.count) weekly milestones complete")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(HomeUI.primaryInk)

                            WeeklyProgressStripView(
                                procedureName: primaryProcedureName,
                                checkIns: activeWeeklyCheckIns,
                                onTapPending: { onNavigateToJournal?() }
                            )
                        }
                    }
                    .frame(width: 154)
                }
            }
        }
    }

    private func timelineCard(entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.75))
                .frame(height: 92)
                .overlay(
                    Group {
                        if entry.photoUrl != nil || entry.photoPath != nil {
                            Image(systemName: "photo")
                                .font(.system(size: 22))
                                .foregroundColor(HomeUI.primary.opacity(0.5))
                        }
                    }
                )

            Text("Day \(entry.dayNumber)")
                .font(.custom("Outfit-SemiBold", size: 12))
                .foregroundColor(HomeUI.text)

            Text(entry.notes?.isEmpty == false ? "Daily photo saved" : entry.entryDate)
                .font(.custom("Outfit-Regular", size: 11))
                .foregroundColor(HomeUI.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(HomeUI.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var recentJournalSection: some View {
        if let entry = latestEntry {
            ModernHomeCard(background: HomeUI.surface, padding: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HomeEyebrow("Recent Journal", color: HomeUI.muted)
                            Text(entry.entryDateAsDate.formatted(.dateTime.weekday(.wide)))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(HomeUI.text)
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
                    }
                    .padding(16)
                    .background(HomeUI.card)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
        }
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

private struct HomeStatCard: View {
    let title: String
    let value: String
    let background: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeEyebrow(title, color: HomeUI.muted)
            Text(value)
                .font(.custom("Outfit-SemiBold", size: 18))
                .foregroundColor(HomeUI.primaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(16)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ScoreBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            HomeEyebrow(title, color: HomeUI.muted)
                .multilineTextAlignment(.center)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(HomeUI.rose)
        }
        .frame(width: 128)
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .background(HomeUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ActionPill: View {
    let title: String
    let foreground: Color
    let background: Color

    var body: some View {
        Text(title)
            .font(.custom("Outfit-SemiBold", size: 13.5))
            .foregroundColor(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(background)
            .clipShape(Capsule())
    }
}

private struct StatusChip: View {
    let title: String
    let foreground: Color
    let background: Color

    var body: some View {
        Text(title)
            .font(.custom("Outfit-Bold", size: 11))
            .tracking(1.8)
            .foregroundColor(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(background)
            .clipShape(Capsule())
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

private struct SummaryStatusCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeEyebrow(title, color: HomeUI.muted)
            Text(value)
                .font(.custom("Outfit-SemiBold", size: 14))
                .foregroundColor(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(HomeUI.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MetricBarRow: View {
    let metric: (label: String, value: Double, color: Color)

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(metric.label)
                    .font(.custom("Outfit-Regular", size: 12))
                    .foregroundColor(HomeUI.muted)
                Spacer()
                Text("\(Int(metric.value.rounded()))/10")
                    .font(.custom("Outfit-SemiBold", size: 12))
                    .foregroundColor(HomeUI.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white)
                    Capsule()
                        .fill(metric.color)
                        .frame(width: geo.size.width * CGFloat(metric.value / 10.0))
                }
            }
            .frame(height: 8)
        }
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
            .shadow(color: HomeUI.shadow, radius: 22, x: 0, y: 10)
    }
}

#Preview {
    PostLoginHomeView()
}
