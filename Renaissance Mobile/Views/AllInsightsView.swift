//
//  AllInsightsView.swift
//  Renaissance Mobile
//
//  Full-screen AI insight reveal. Design based on rena-ai-insight-reveal.html.
//  "See all" destination from the Rena Insights carousel.
//
//  Supports lazy loading: present immediately after saving an entry and show
//  a spinner + cycling encouragements while Rena is analysing in the background.
//  The view observes JournalViewModel reactively and transitions to full content
//  as soon as insights land.
//

import SwiftUI

// MARK: - Design tokens

private enum AI {
    static let primary  = Color(hex: "#8E4C5C")
    static let gradA    = Color(hex: "#6B3346")
    static let gradB    = Color(hex: "#B76E79")
    static let accent   = Color(hex: "#C4929A")
    static let textHi   = Color(hex: "#3D2B2E")
    static let textMid  = Color(hex: "#6B4F53")
    static let textLo   = Color(hex: "#B8A9AB")
    static let border   = Color(hex: "#C4929A").opacity(0.18)
    static let bgTop    = Color(hex: "#FFF8F6")
    static let bgMid    = Color(hex: "#FAF0F2")
    static let bgBot    = Color(hex: "#F5E8EE")
}

// MARK: - View

struct AllInsightsView: View {
    let vm: JournalViewModel
    let procedureId: String
    let procedureName: String
    var scrollAnchor: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showSocialShare = false
    @State private var loadingMessageIndex = 0

    private var insights: RecoveryInsights? { vm.insights[procedureId] }
    private var isGenerating: Bool { vm.insightsGenerating.contains(procedureId) }

    private let loadingMessages: [String] = [
        "You showed up for yourself today.",
        "Consistency is one of the strongest predictors of a smooth recovery.",
        "Every entry helps Rena understand your unique healing pattern.",
        "Your dedication to logging is already making a difference.",
        "Rena is connecting the dots across your recovery journey.",
        "Almost there — your personalized insights are being prepared."
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            // Cream → pale blush → soft rose gradient background
            LinearGradient(
                stops: [
                    .init(color: AI.bgTop, location: 0),
                    .init(color: AI.bgMid, location: 0.4),
                    .init(color: AI.bgBot, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let insights {
                insightsContent(insights)
            } else {
                loadingContent
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Loading State

    private var loadingContent: some View {
        VStack(spacing: 0) {
            topBar

            Spacer()

            VStack(spacing: 28) {
                // AI logo mark
                aiLogoMark

                // Title
                VStack(spacing: 6) {
                    Text("Rena's Reflection")
                        .font(.system(size: 28, weight: .medium, design: .serif))
                        .foregroundColor(AI.textHi)

                    Text("Based on your \(procedureName) recovery")
                        .font(.custom("Outfit-Regular", size: 12))
                        .foregroundColor(AI.textLo)
                }
                .multilineTextAlignment(.center)

                // Spinner + status
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(AI.accent)
                        .scaleEffect(1.2)

                    Text("Analyzing your recovery journey...")
                        .font(.custom("Outfit-Regular", size: 12))
                        .foregroundColor(AI.textLo)
                }

                // Cycling encouragement card
                VStack(spacing: 0) {
                    Text(loadingMessages[loadingMessageIndex])
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(AI.textHi)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(loadingMessageIndex)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.easeInOut(duration: 0.5), value: loadingMessageIndex)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.60))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AI.border, lineWidth: 1))
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .task {
            // Cycle through messages every 2.8 s while loading
            while isGenerating || insights == nil {
                try? await Task.sleep(nanoseconds: 2_800_000_000)
                withAnimation {
                    loadingMessageIndex = (loadingMessageIndex + 1) % loadingMessages.count
                }
            }
        }
    }

    // MARK: - Insights Content

    private func insightsContent(_ insights: RecoveryInsights) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    topBar

                    // Entry saved chip
                    entrySavedChip(insights)
                        .padding(.top, 12)

                    // AI logo mark (large)
                    aiLogoMark
                        .padding(.top, 28)

                    // Heading
                    Text("Rena's Reflection")
                        .font(.system(size: 28, weight: .medium, design: .serif))
                        .foregroundColor(AI.textHi)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)

                    Text("Based on your \(insights.procedureName) recovery")
                        .font(.custom("Outfit-Regular", size: 12))
                        .foregroundColor(AI.textLo)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    // Decorative gradient divider
                    LinearGradient(
                        colors: [.clear, AI.accent, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 40, height: 1)
                    .padding(.top, 20)

                    // Main insight card (summary)
                    InsightRevealCard(label: "RENA INSIGHT", text: insights.summary)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    // Trend chip
                    trendChip(insights)
                        .padding(.horizontal, 24)
                        .padding(.top, 14)

                    // Next steps
                    if let nextSteps = insights.nextSteps {
                        InsightRevealCard(
                            label: "NEXT STEPS",
                            text: nextSteps,
                            icon: "list.bullet"
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                        .id("nextSteps")
                    }

                    // Flags
                    if !insights.flags.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(Array(insights.flags.enumerated()), id: \.offset) { _, flag in
                                FlagRevealCard(flag: flag)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                        .id("flags")
                    }

                    // All encouragements
                    if !insights.encouragements.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(Array(insights.encouragements.enumerated()), id: \.offset) { _, enc in
                                InsightRevealCard(label: "ENCOURAGEMENT", text: enc, icon: "star.fill")
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                        .id("encouragements")
                    }

                    // Weekly summaries for completed check-ins
                    weeklySummarySection
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                        .padding(.bottom, 24)
                        .id("weeklySummaries")
                }
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ctaStack(insights)
            }
            .onAppear {
                guard let anchor = scrollAnchor else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(anchor, anchor: .top)
                    }
                }
            }
        }
    }

    // MARK: - Weekly Summary Section

    private var completedCheckIns: [WeeklyCheckIn] {
        vm.checkIns(for: procedureId)
            .filter(\.isCompleted)
            .sorted { $0.weekNumber < $1.weekNumber }
    }

    @ViewBuilder
    private var weeklySummarySection: some View {
        let checkIns = completedCheckIns
        if !checkIns.isEmpty && vm.insightsEnabled {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                LinearGradient(colors: [AI.gradA, AI.gradB],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: 12, height: 2)
                        Text("AUTO WEEKLY REPORTS")
                            .font(.custom("Outfit-SemiBold", size: 10))
                            .kerning(1.0)
                            .foregroundColor(AI.primary)
                    }
                    Text("Daily logs turned into trends, alerts, and a recovery score.")
                        .font(.custom("Outfit-Regular", size: 12))
                        .foregroundColor(AI.textLo)
                }

                ForEach(checkIns, id: \.weekNumber) { checkIn in
                    let key = vm.weeklySummaryKey(procedureId, checkIn.weekNumber)
                    let summary = vm.weeklySummaries[key]
                    let isGenerating = vm.weeklySummaryGenerating.contains(key)

                    WeeklySummaryCard(
                        weekNumber: checkIn.weekNumber,
                        summary: summary,
                        isGenerating: isGenerating,
                        satisfaction: vm.weeklySatisfaction(for: procedureId, weekNumber: checkIn.weekNumber),
                        onRateSatisfaction: { rating in
                            vm.setWeeklySatisfaction(rating, for: procedureId, weekNumber: checkIn.weekNumber)
                        }
                    )
                    .task {
                        // Lazy-generate: trigger if not cached and not already in-flight
                        guard summary == nil, !isGenerating else { return }
                        await vm.refreshWeeklySummary(
                            for: procedureId,
                            procedureName: procedureName,
                            weekNumber: checkIn.weekNumber
                        )
                    }
                }
            }
        }
    }

    // MARK: - Shared subviews

    private var topBar: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AI.textHi)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AI.border, lineWidth: 1))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private func entrySavedChip(_ insights: RecoveryInsights) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(AI.primary)
                .frame(width: 6, height: 6)
            Text("\(insights.procedureName) · \(insights.trend.label)")
                .font(.custom("Outfit-SemiBold", size: 12))
                .foregroundColor(AI.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(AI.primary.opacity(0.08))
        .overlay(Capsule().stroke(AI.primary.opacity(0.15), lineWidth: 1))
        .clipShape(Capsule())
    }

    private var aiLogoMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [AI.gradA, AI.gradB],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .shadow(color: Color(hex: "#6B3346").opacity(0.30), radius: 20, x: 0, y: 12)

            ZStack {
                Circle().stroke(Color.white.opacity(0.20), lineWidth: 1.2).frame(width: 40, height: 40)
                Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.2).frame(width: 28, height: 28)
                Circle().stroke(Color.white.opacity(0.55), lineWidth: 1.2).frame(width: 16, height: 16)
                Circle().fill(Color.white.opacity(0.95)).frame(width: 7, height: 7)
            }
        }
    }

    private func trendChip(_ insights: RecoveryInsights) -> some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(trendColor(insights.trend))
                    .frame(width: 8, height: 8)
                Text(insights.trend.label)
                    .font(.custom("Outfit-SemiBold", size: 12))
                    .foregroundColor(AI.textMid)
                Text("· \(insights.entryCount) \(insights.entryCount == 1 ? "entry" : "entries")")
                    .font(.custom("Outfit-Regular", size: 12))
                    .foregroundColor(AI.textLo)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.65))
            .overlay(Capsule().stroke(AI.border, lineWidth: 1))
            .clipShape(Capsule())

            Spacer()

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(sparklineHeights(insights.trend).enumerated()), id: \.offset) { idx, h in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(idx == sparklineHeights(insights.trend).count - 1 ? AI.primary : AI.accent.opacity(0.4))
                        .frame(width: 5, height: h)
                }
            }
            .frame(height: 20)
        }
    }

    private func trendColor(_ trend: TrendDirection) -> Color {
        switch trend {
        case .improving:  return Color(hex: "#7ABF7A")
        case .stable:     return AI.accent
        case .concerning: return AI.gradB
        }
    }

    private func sparklineHeights(_ trend: TrendDirection) -> [CGFloat] {
        switch trend {
        case .improving:  return [6, 9, 12, 16, 18]
        case .stable:     return [10, 12, 10, 13, 11]
        case .concerning: return [14, 12, 10, 8, 6]
        }
    }

    private func ctaStack(_ insights: RecoveryInsights) -> some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, AI.bgBot.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)

            VStack(spacing: 10) {
                Button { showSocialShare = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Share to Social Media")
                            .font(.custom("Outfit-SemiBold", size: 14))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AI.gradA, AI.gradB],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color(hex: "#6B3346").opacity(0.25), radius: 12, x: 0, y: 8)
                }
                .sheet(isPresented: $showSocialShare) {
                    SocialShareSheet(insights: insights)
                        .presentationDetents([.height(280)])
                        .presentationDragIndicator(.hidden)
                }

                Button { dismiss() } label: {
                    Text("Back to my journal")
                        .font(.custom("Outfit-Regular", size: 14))
                        .foregroundColor(AI.textMid)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
            .background(AI.bgBot.opacity(0.95))
        }
    }
}

// MARK: - Insight Reveal Card (frosted glass, italic serif)

private struct InsightRevealCard: View {
    let label: String
    let text: String
    var accent: Color = Color(hex: "#8E4C5C")
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#6B3346"), Color(hex: "#B76E79")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 12, height: 2)

                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(accent)
                }

                Text(label)
                    .font(.custom("Outfit-SemiBold", size: 10))
                    .kerning(1.0)
                    .foregroundColor(accent)
            }

            Text(text)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(Color(hex: "#3D2B2E"))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.70))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#C4929A").opacity(0.20), lineWidth: 1)
        )
    }
}

// MARK: - Flag Reveal Card

private struct FlagRevealCard: View {
    let flag: InsightFlag

    private var accentColor: Color {
        switch flag.severity {
        case .urgent:  return Color(hex: "#B76E79")
        case .warning: return Color(hex: "#C4929A")
        case .info:    return Color(hex: "#8E4C5C")
        }
    }

    private var severityLabel: String {
        switch flag.severity {
        case .urgent:  return "CONCERN"
        case .warning: return "WARNING"
        case .info:    return "NOTE"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(accentColor)
                    .frame(width: 12, height: 2)

                Image(systemName: flag.severity.systemImage)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(accentColor)

                Text(severityLabel)
                    .font(.custom("Outfit-SemiBold", size: 10))
                    .kerning(1.0)
                    .foregroundColor(accentColor)

                if let metric = flag.metric {
                    Text("· \(metric)")
                        .font(.custom("Outfit-Regular", size: 10))
                        .foregroundColor(Color(hex: "#B8A9AB"))
                }
            }

            Text(flag.message)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(Color(hex: "#3D2B2E"))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.70))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(accentColor.opacity(0.20), lineWidth: 1)
        )
    }
}

// MARK: - Weekly Summary Card

private struct WeeklySummaryCard: View {
    let weekNumber: Int
    let summary: WeeklySummary?
    let isGenerating: Bool
    let satisfaction: Int?
    let onRateSatisfaction: (Int) -> Void

    private let gradA  = Color(hex: "#6B3346")
    private let gradB  = Color(hex: "#B76E79")
    private let accent = Color(hex: "#C4929A")
    private let textHi = Color(hex: "#3D2B2E")
    private let textLo = Color(hex: "#B8A9AB")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Week label
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [gradA, gradB],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 24, height: 24)
                    Text("\(weekNumber)")
                        .font(.custom("Outfit-SemiBold", size: 11))
                        .foregroundColor(.white)
                }
                Text("Week \(weekNumber)")
                    .font(.custom("Outfit-SemiBold", size: 13))
                    .foregroundColor(textHi)
                Spacer()
                if isGenerating {
                    ProgressView().scaleEffect(0.75).tint(accent)
                }
            }

            if let summary {
                Text(summary.headline)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .italic()
                    .foregroundColor(textHi)

                if let score = summary.recoveryScore {
                    HStack(spacing: 8) {
                        Text("Recovery Score \(score)/100")
                            .font(.custom("Outfit-SemiBold", size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(colors: [gradA, gradB], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                    }
                }

                Text(summary.observation)
                    .font(.custom("Outfit-Regular", size: 13))
                    .foregroundColor(textHi.opacity(0.75))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    summaryMetricRow("Pain trend", value: summary.painTrend ?? "Not enough data")
                    summaryMetricRow("Swelling", value: summary.swellingStatus ?? "Not enough data")
                    summaryMetricRow("Bruising", value: summary.bruisingStatus ?? "Not enough data")
                }

                if !summary.metricPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pain chart")
                            .font(.custom("Outfit-SemiBold", size: 12))
                            .foregroundColor(textHi)
                        Text(painChartText(summary.metricPoints))
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundColor(gradA)
                    }
                }

                if !summary.alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Alerts")
                            .font(.custom("Outfit-SemiBold", size: 12))
                            .foregroundColor(textHi)
                        ForEach(summary.alerts, id: \.self) { alert in
                            VStack(alignment: .leading, spacing: 6) {
                                summaryChip(
                                    icon: alert.severity.systemImage,
                                    color: alert.severity == .info ? accent : gradB,
                                    text: alert.title
                                )
                                Text(alert.explanation)
                                    .font(.custom("Outfit-Regular", size: 12))
                                    .foregroundColor(textHi.opacity(0.72))
                                    .fixedSize(horizontal: false, vertical: true)
                                if let nextStep = alert.recommendedNextStep {
                                    Text("Next: \(nextStep)")
                                        .font(.custom("Outfit-SemiBold", size: 11))
                                        .foregroundColor(textHi)
                                }
                            }
                        }
                    }
                }

                if summary.improvement != nil || summary.concern != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        if let imp = summary.improvement {
                            summaryChip(
                                icon: "arrow.up.circle.fill",
                                color: Color(hex: "#7ABF7A"),
                                text: imp
                            )
                        }
                        if let con = summary.concern {
                            summaryChip(
                                icon: "exclamationmark.circle.fill",
                                color: gradB,
                                text: con
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Overall satisfaction")
                        .font(.custom("Outfit-SemiBold", size: 12))
                        .foregroundColor(textHi)
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { rating in
                            Button {
                                onRateSatisfaction(rating)
                            } label: {
                                Text("\(rating)")
                                    .font(.custom("Outfit-SemiBold", size: 12))
                                    .foregroundColor((satisfaction ?? 0) >= rating ? .white : gradA)
                                    .frame(width: 30, height: 30)
                                    .background((satisfaction ?? 0) >= rating ? gradA : Color.white.opacity(0.7))
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(gradA.opacity(0.16), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else if isGenerating {
                Text("Analyzing this week's entries…")
                    .font(.custom("Outfit-Regular", size: 13))
                    .foregroundColor(textLo)
            } else {
                Text("No data available for this week.")
                    .font(.custom("Outfit-Regular", size: 13))
                    .foregroundColor(textLo)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.70))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#C4929A").opacity(0.18), lineWidth: 1)
        )
    }

    private func painChartText(_ points: [WeeklyMetricPoint]) -> String {
        let values = points.compactMap { point in
            point.painLevel.map { String(Int($0.rounded())) }
        }
        return values.isEmpty ? "Not enough pain logs yet" : values.joined(separator: " → ")
    }

    private func summaryMetricRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom("Outfit-Regular", size: 12))
                .foregroundColor(textLo)
            Spacer()
            Text(value)
                .font(.custom("Outfit-SemiBold", size: 12))
                .foregroundColor(textHi)
        }
    }

    private func summaryChip(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .padding(.top, 1)
            Text(text)
                .font(.custom("Outfit-Regular", size: 12))
                .foregroundColor(Color(hex: "#3D2B2E").opacity(0.8))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview {
    let vm = JournalViewModel()
    vm.insights["preview"] = RecoveryInsights(
        summary: "Your recovery is progressing well. The swelling has reduced significantly from Day 1 to Day 7, which is typical of rhinoplasty healing. Your notes reflect a positive mindset which correlates with better recovery outcomes.",
        trend: .improving,
        flags: [
            InsightFlag(severity: .warning, message: "Bruising levels are still elevated. Arnica gel may help reduce discoloration faster.", metric: "Bruising"),
            InsightFlag(severity: .info, message: "Sleeping with your head elevated at 30–45 degrees will help reduce swelling overnight.", metric: nil)
        ],
        encouragements: ["You're doing great! Consistency in logging is a strong predictor of recovery awareness.", "Keep up the momentum — every entry tells Rena more about your unique healing pattern."],
        nextSteps: "Continue sleeping with your head elevated for the next 5 days. Avoid strenuous activity and direct sun exposure. Apply arnica gel twice daily to bruised areas.",
        procedureId: "preview",
        procedureName: "Rhinoplasty",
        generatedAt: Date(),
        entryCount: 7
    )
    return AllInsightsView(vm: vm, procedureId: "preview", procedureName: "Rhinoplasty")
}
