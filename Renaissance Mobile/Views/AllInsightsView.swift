//
//  AllInsightsView.swift
//  Renaissance Mobile
//
//  Full-screen AI insight reveal. Design based on rena-ai-insight-reveal.html.
//  "See all" destination from the Rena Insights carousel.
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
    let insights: RecoveryInsights
    var scrollAnchor: String? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var showSocialShare = false

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

            // Scrollable content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        topBar

                        // Entry saved chip
                        entrySavedChip
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

                        // Trend chip (replaces mood tag from HTML)
                        trendChip
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

                        // All encouragements (first shown in carousel, rest shown here)
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

                        // Space for pinned CTAs
                        Color.clear.frame(height: 130)
                    }
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    guard let anchor = scrollAnchor else { return }
                    // Defer so the scroll view has laid out before we jump
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(anchor, anchor: .top)
                        }
                    }
                }
            }

            // Pinned bottom CTAs
            ctaStack
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Top Bar

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

    // MARK: - Entry Saved Chip

    private var entrySavedChip: some View {
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

    // MARK: - AI Logo Mark (large, 80pt)

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

            // Concentric circles (matches HTML SVG)
            ZStack {
                Circle().stroke(Color.white.opacity(0.20), lineWidth: 1.2).frame(width: 40, height: 40)
                Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.2).frame(width: 28, height: 28)
                Circle().stroke(Color.white.opacity(0.55), lineWidth: 1.2).frame(width: 16, height: 16)
                Circle().fill(Color.white.opacity(0.95)).frame(width: 7, height: 7)
            }
        }
    }

    // MARK: - Trend Chip (replaces mood tag)

    private var trendChip: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(trendColor)
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

            // Decorative sparkline bars
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(sparklineHeights.enumerated()), id: \.offset) { idx, h in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(idx == sparklineHeights.count - 1 ? AI.primary : AI.accent.opacity(0.4))
                        .frame(width: 5, height: h)
                }
            }
            .frame(height: 20)
        }
    }

    private var trendColor: Color {
        switch insights.trend {
        case .improving:  return Color(hex: "#7ABF7A")
        case .stable:     return AI.accent
        case .concerning: return AI.gradB
        }
    }

    private var sparklineHeights: [CGFloat] {
        switch insights.trend {
        case .improving:  return [6, 9, 12, 16, 18]
        case .stable:     return [10, 12, 10, 13, 11]
        case .concerning: return [14, 12, 10, 8, 6]
        }
    }

    // MARK: - Pinned CTAs

    private var ctaStack: some View {
        VStack(spacing: 0) {
            // Subtle fade above buttons
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
            // Label row with gradient bar
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

            // Insight text — italic serif (Cormorant Garamond style via system serif)
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

// MARK: - Preview

#Preview {
    AllInsightsView(insights: RecoveryInsights(
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
    ))
}
