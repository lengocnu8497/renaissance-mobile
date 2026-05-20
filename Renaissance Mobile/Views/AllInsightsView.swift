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
    static let primary  = Color(hex: "#6C63FF")
    static let gradA    = Color(hex: "#4A41C8")
    static let gradB    = Color(hex: "#9B95E0")
    static let accent   = Color(hex: "#9B95E0")
    static let textHi   = Color(hex: "#2D2575")
    static let textMid  = Color(hex: "#7B6FC0")
    static let textLo   = Color(hex: "#A9A3D4")
    static let border   = Color(hex: "#D4CCFF").opacity(0.5)
    static let soft     = Color(hex: "#EAE7FF")
    static let bgTop    = Color(hex: "#F8F8FF")
    static let bgMid    = Color(hex: "#F4F3FF")
    static let bgBot    = Color(hex: "#EEEEFF")

    static func head(_ size: CGFloat) -> Font  { .custom("Manrope", size: size).weight(.bold) }
    static func semi(_ size: CGFloat) -> Font  { .custom("PlusJakartaSans-SemiBold", size: size) }
    static func reg(_ size: CGFloat)  -> Font  { .custom("PlusJakartaSans-Regular",  size: size) }
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
    @State private var screenHeight: CGFloat = 0

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
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
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
            .onAppear { screenHeight = geo.size.height }
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
                aiLogoMark

                VStack(spacing: 6) {
                    Text("Rena's Reflection")
                        .font(.system(size: 28, weight: .medium, design: .serif))
                        .foregroundColor(AI.textHi)

                    Text("Based on your \(procedureName) recovery")
                        .font(AI.reg(12))
                        .foregroundColor(AI.textLo)
                }
                .multilineTextAlignment(.center)

                VStack(spacing: 14) {
                    ProgressView()
                        .tint(AI.accent)
                        .scaleEffect(1.2)

                    Text("Analyzing your recovery journey...")
                        .font(AI.reg(12))
                        .foregroundColor(AI.textLo)
                }

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

                    entrySavedChip(insights)
                        .padding(.top, 12)

                    aiLogoMark
                        .padding(.top, 24)

                    Text("Rena's Reflection")
                        .font(.system(size: 28, weight: .medium, design: .serif))
                        .foregroundColor(AI.textHi)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)

                    Text("Based on your \(insights.procedureName) recovery")
                        .font(AI.reg(12))
                        .foregroundColor(AI.textLo)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    LinearGradient(
                        colors: [.clear, AI.accent, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 40, height: 1)
                    .padding(.top, 20)

                    InsightRevealCard(label: "RENA INSIGHT", text: insights.summary)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    trendChip(insights)
                        .padding(.horizontal, 24)
                        .padding(.top, 14)

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
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(LinearGradient(colors: [AI.gradA, AI.gradB],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: 3, height: 14)
                            .clipShape(Capsule())
                        Text("WEEKLY REPORTS")
                            .font(AI.semi(10))
                            .tracking(1.8)
                            .foregroundColor(AI.primary)
                    }
                    Text("Daily logs turned into trends, alerts, and recovery insights.")
                        .font(AI.reg(12))
                        .foregroundColor(AI.textLo)
                        .padding(.leading, 11)
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
                .font(AI.semi(12))
                .foregroundColor(AI.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(AI.primary.opacity(0.08))
        .overlay(Capsule().stroke(AI.primary.opacity(0.15), lineWidth: 1))
        .clipShape(Capsule())
    }

    private var aiLogoMark: some View {
        let size = screenHeight > 0 ? screenHeight * 3 / 8 : 135
        return LottieView(name: "rena-lottie")
            .frame(width: size, height: size)
    }

    private func trendChip(_ insights: RecoveryInsights) -> some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(trendColor(insights.trend))
                    .frame(width: 8, height: 8)
                Text(insights.trend.label)
                    .font(AI.semi(12))
                    .foregroundColor(AI.textMid)
                Text("· \(insights.entryCount) \(insights.entryCount == 1 ? "entry" : "entries")")
                    .font(AI.reg(12))
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
                            .font(AI.semi(14))
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
                    .shadow(color: Color(hex: "#4A41C8").opacity(0.20), radius: 12, x: 0, y: 8)
                }
                .sheet(isPresented: $showSocialShare) {
                    SocialShareSheet(insights: insights)
                        .presentationDetents([.height(280)])
                        .presentationDragIndicator(.hidden)
                }

                Button { dismiss() } label: {
                    Text("Back to my journal")
                        .font(AI.reg(14))
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

// MARK: - Insight Reveal Card

private struct InsightRevealCard: View {
    let label: String
    let text: String
    var accent: Color = Color(hex: "#6C63FF")
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#4A41C8"), Color(hex: "#9B95E0")],
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
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .tracking(1.2)
                    .foregroundColor(accent)
            }

            Text(text)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(Color(hex: "#2D2575"))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.70))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#D4CCFF").opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Flag Reveal Card

private struct FlagRevealCard: View {
    let flag: InsightFlag

    private var accentColor: Color {
        switch flag.severity {
        case .urgent:  return Color(hex: "#C97070")
        case .warning: return Color(hex: "#C4A45A")
        case .info:    return Color(hex: "#6C63FF")
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
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .tracking(1.2)
                    .foregroundColor(accentColor)

                if let metric = flag.metric {
                    Text("· \(metric)")
                        .font(.custom("PlusJakartaSans-Regular", size: 10))
                        .foregroundColor(Color(hex: "#A9A3D4"))
                }
            }

            Text(flag.message)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(Color(hex: "#2D2575"))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.70))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(accentColor.opacity(0.25), lineWidth: 1)
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

    private let gradA  = Color(hex: "#4A41C8")
    private let gradB  = Color(hex: "#9B95E0")
    private let primary = Color(hex: "#6C63FF")
    private let soft   = Color(hex: "#EAE7FF")
    private let textHi = Color(hex: "#2D2575")
    private let textMid = Color(hex: "#7B6FC0")
    private let textLo = Color(hex: "#A9A3D4")

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Week header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [gradA, gradB],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 26, height: 26)
                    Text("\(weekNumber)")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Week \(weekNumber) summary")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                        .foregroundColor(textHi)
                    Text("Auto-generated from your daily logs")
                        .font(.custom("PlusJakartaSans-Regular", size: 11))
                        .foregroundColor(textLo)
                }
                Spacer()
                if isGenerating {
                    ProgressView().scaleEffect(0.75).tint(gradB)
                }
            }

            if let summary {
                // Headline
                Text(summary.headline)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .italic()
                    .foregroundColor(textHi)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Observation
                Text(summary.observation)
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundColor(textHi.opacity(0.75))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Metric rows — left-border timeline style
                VStack(alignment: .leading, spacing: 0) {
                    metricTimelineRow("Pain trend",  value: summary.painTrend    ?? "Not enough data")
                    metricTimelineRow("Swelling",    value: summary.swellingStatus ?? "Not enough data")
                    metricTimelineRow("Bruising",    value: summary.bruisingStatus ?? "Not enough data")
                }

                // Pain chart (text sparkline)
                if !summary.metricPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PAIN TREND")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                            .tracking(1.5)
                            .foregroundColor(textMid)
                        Text(painChartText(summary.metricPoints))
                            .font(.system(size: 15, weight: .regular, design: .serif))
                            .foregroundColor(gradA)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(soft.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Alerts
                if !summary.alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ALERTS")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                            .tracking(1.5)
                            .foregroundColor(textMid)
                        ForEach(summary.alerts, id: \.self) { alert in
                            alertRow(alert)
                        }
                    }
                }

                // Improvement / concern chips
                if summary.improvement != nil || summary.concern != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        if let imp = summary.improvement {
                            signalChip(icon: "arrow.up.circle.fill", color: Color(hex: "#7ABF7A"), text: imp)
                        }
                        if let con = summary.concern {
                            signalChip(icon: "exclamationmark.circle.fill", color: gradB, text: con)
                        }
                    }
                }

                // Satisfaction rating
                VStack(alignment: .leading, spacing: 8) {
                    Text("OVERALL SATISFACTION")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                        .tracking(1.5)
                        .foregroundColor(textMid)
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { rating in
                            Button {
                                onRateSatisfaction(rating)
                            } label: {
                                Text("\(rating)")
                                    .font(.custom("PlusJakartaSans-SemiBold", size: 12))
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
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundColor(textLo)
            } else {
                Text("No data available for this week.")
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundColor(textLo)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.70))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#D4CCFF").opacity(0.5), lineWidth: 1)
        )
    }

    // Timeline-style metric row (left 2px violet border)
    private func metricTimelineRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Color(hex: "#EAE7FF"))
                .frame(width: 2)
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .tracking(0.3)
                    .foregroundColor(primary)
                Text(value)
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundColor(textHi.opacity(0.75))
                    .lineSpacing(2)
            }
            .padding(.leading, 10)
            .padding(.vertical, 6)
        }
    }

    private func alertRow(_ alert: RecoveryAlert) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: alert.severity.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(alert.severity == .info ? primary : gradB)
                Text(alert.title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                    .foregroundColor(textHi)
            }
            Text(alert.explanation)
                .font(.custom("PlusJakartaSans-Regular", size: 12))
                .foregroundColor(textHi.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            if let nextStep = alert.recommendedNextStep {
                Text("Next: \(nextStep)")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .foregroundColor(textHi)
            }
        }
    }

    private func signalChip(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .padding(.top, 1)
            Text(text)
                .font(.custom("PlusJakartaSans-Regular", size: 12))
                .foregroundColor(Color(hex: "#2D2575").opacity(0.8))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func painChartText(_ points: [WeeklyMetricPoint]) -> String {
        let values = points.compactMap { point in
            point.painLevel.map { String(Int($0.rounded())) }
        }
        return values.isEmpty ? "Not enough pain logs yet" : values.joined(separator: " → ")
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
