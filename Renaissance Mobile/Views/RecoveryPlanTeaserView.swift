//
//  RecoveryPlanTeaserView.swift
//  Renaissance Mobile
//

import SwiftUI

private enum RecoveryPlanTeaserUI {
    static let shell = Color(hex: "#EEF1E8")
    static let bg = Color(hex: "#F6F7F2")
    static let card = Color.white.opacity(0.88)
    static let cardSoft = Color(hex: "#EDF1E8")
    static let current = Color(hex: "#F1DDDA")
    static let line = Color.black.opacity(0.06)
    static let text = Color(hex: "#1F261D")
    static let muted = Color(hex: "#687064")
    static let primary = Color(hex: "#516048")
    static let primaryInk = Color(hex: "#314030")
    static let primarySoft = Color(hex: "#D9E3CE")
    static let rose = Color(hex: "#B07B7A")
    static let roseDeep = Color(hex: "#976769")
    static let shadow = Color(red: 90/255, green: 103/255, blue: 80/255).opacity(0.10)
}

struct RecoveryPlanTeaserView: View {
    @State private var viewModel: RecoveryPlanViewModel

    private let journalViewModel: JournalViewModel?
    private let onUnlock: () -> Void

    init(
        viewModel: RecoveryPlanViewModel? = nil,
        journalViewModel: JournalViewModel? = nil,
        onUnlock: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel ?? RecoveryPlanViewModel())
        self.journalViewModel = journalViewModel
        self.onUnlock = onUnlock
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            Group {
                if viewModel.isLoading && !viewModel.hasPlan {
                    loadingState
                } else if let plan = viewModel.plan {
                    roadmapOnlyCard(for: plan)
                } else if let errorMessage = viewModel.errorMessage {
                    errorCard(message: errorMessage)
                } else {
                    loadingState
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(background.ignoresSafeArea())
        .task {
            guard !viewModel.hasPlan, !viewModel.isLoading else { return }
            await viewModel.load(journalViewModel: journalViewModel)
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#F8FAF4"), RecoveryPlanTeaserUI.bg],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(RecoveryPlanTeaserUI.rose.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .offset(x: 120, y: -260)

            Circle()
                .fill(RecoveryPlanTeaserUI.primary.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 24)
                .offset(x: -140, y: -120)
        }
    }

    private func roadmapOnlyCard(for plan: PersonalizedRecoveryPlan) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(RecoveryPlanTeaserUI.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(RecoveryPlanTeaserUI.line, lineWidth: 1)
                    )
                    .shadow(color: RecoveryPlanTeaserUI.shadow, radius: 22, x: 0, y: 10)

                Circle()
                    .fill(RecoveryPlanTeaserUI.rose.opacity(0.10))
                    .frame(width: 180, height: 180)
                    .blur(radius: 18)
                    .offset(x: 38, y: -44)

                VStack(alignment: .leading, spacing: 14) {
                    roadmapTimeline(for: plan)

                    Button(action: onUnlock) {
                        Text("Unlock My Full Recovery Plan")
                            .font(.custom("Manrope", size: 16).weight(.semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(RecoveryPlanTeaserUI.primary)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func roadmapTimeline(for plan: PersonalizedRecoveryPlan) -> some View {
        let visiblePhases = roadmapPhases(for: plan)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [RecoveryPlanTeaserUI.rose.opacity(0.36), RecoveryPlanTeaserUI.primary.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2)
                .padding(.leading, 8)
                .padding(.vertical, 18)

            VStack(spacing: 14) {
                ForEach(Array(visiblePhases.enumerated()), id: \.element.phase.id) { index, item in
                    roadmapPhaseRow(
                        phase: item.phase,
                        access: item.access,
                        isCurrent: item.phase.status == .current
                    )
                }
            }
        }
    }

    private func roadmapPhaseRow(
        phase: RecoveryPlanPhase,
        access: PhaseAccess,
        isCurrent: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            roadmapNode(isCurrent: isCurrent)
                .padding(.top, 20)

            ZStack {
                roadmapPhaseBackground(isCurrent: isCurrent)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(access.roadmapLabel)
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(RecoveryPlanTeaserUI.roseDeep)

                            Text(phase.title)
                                .font(.custom("Manrope", size: isCurrent ? 22 : 20).weight(.bold))
                                .foregroundStyle(RecoveryPlanTeaserUI.primaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        Text(access.roadmapRangeText(for: phase))
                            .font(.custom("Manrope", size: 12).weight(.semibold))
                            .foregroundStyle(RecoveryPlanTeaserUI.muted)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(RecoveryPlanTeaserUI.cardSoft)
                            )
                    }

                    Group {
                        if access == .locked {
                            roadmapBlurredContent(for: phase)
                        } else {
                            roadmapVisibleContent(for: phase, access: access)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                if access == .locked {
                    roadmapLockedOverlay
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(RecoveryPlanTeaserUI.card)
                .frame(height: 560)
                .overlay(alignment: .topLeading) {
                    VStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(index == 0 ? RecoveryPlanTeaserUI.current.opacity(0.55) : Color.white.opacity(0.78))
                                .frame(height: index == 2 ? 168 : 180)
                        }

                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(RecoveryPlanTeaserUI.primary.opacity(0.22))
                            .frame(height: 56)
                    }
                    .padding(16)
                    .redacted(reason: .placeholder)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("We need a little more recovery context")
                .font(.custom("Manrope", size: 22))
                .foregroundStyle(RecoveryPlanTeaserUI.text)

            Text(message)
                .font(.custom("Manrope", size: 14))
                .foregroundStyle(RecoveryPlanTeaserUI.muted)
                .lineSpacing(3)

            Button {
                Task {
                    await viewModel.refresh(journalViewModel: journalViewModel)
                }
            } label: {
                Text("Try again")
                    .font(.custom("Manrope", size: 15).weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(RecoveryPlanTeaserUI.primary)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(RecoveryPlanTeaserUI.card)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(RecoveryPlanTeaserUI.line, lineWidth: 1)
            )
            .shadow(color: RecoveryPlanTeaserUI.shadow, radius: 22, x: 0, y: 10)
    }

    private func phaseAccess(for phase: RecoveryPlanPhase, index: Int) -> PhaseAccess {
        guard viewModel.isLocked else { return .full }
        if phase.status == .current { return .full }
        return .locked
    }

    private func roadmapPhases(for plan: PersonalizedRecoveryPlan) -> [(phase: RecoveryPlanPhase, access: PhaseAccess)] {
        guard let currentIndex = plan.phases.firstIndex(where: { $0.status == .current }) else {
            return Array(plan.phases.enumerated()).map { index, phase in
                (phase, phaseAccess(for: phase, index: index))
            }
        }

        return Array(plan.phases.enumerated())
            .filter { index, _ in index >= currentIndex }
            .map { index, phase in
                (phase, phaseAccess(for: phase, index: index))
            }
    }

    private func roadmapNode(isCurrent: Bool) -> some View {
        Circle()
            .fill(isCurrent ? RecoveryPlanTeaserUI.rose : Color(hex: "#D9DED5"))
            .frame(width: isCurrent ? 18 : 16, height: isCurrent ? 18 : 16)
            .overlay(
                Circle()
                    .stroke(
                        isCurrent
                        ? RecoveryPlanTeaserUI.roseDeep.opacity(0.24)
                        : RecoveryPlanTeaserUI.primary.opacity(0.10),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.white.opacity(0.95), radius: 0, x: 0, y: 0)
    }

    private func roadmapPhaseBackground(isCurrent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                isCurrent
                ? LinearGradient(
                    colors: [RecoveryPlanTeaserUI.current.opacity(0.92), Color.white.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                : LinearGradient(
                    colors: [Color.white.opacity(0.95), Color(hex: "#F8FAF4").opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isCurrent
                        ? RecoveryPlanTeaserUI.rose.opacity(0.24)
                        : RecoveryPlanTeaserUI.line,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isCurrent ? RecoveryPlanTeaserUI.rose.opacity(0.10) : .clear,
                radius: 14,
                x: 0,
                y: 8
            )
    }

    private func roadmapVisibleContent(for phase: RecoveryPlanPhase, access: PhaseAccess) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(roadmapSummary(for: phase, access: access))
                .font(.custom("Manrope", size: 14))
                .foregroundStyle(RecoveryPlanTeaserUI.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(roadmapBullets(for: phase, access: access), id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(RecoveryPlanTeaserUI.rose)
                            .frame(width: 7, height: 7)
                            .padding(.top, 6)

                        Text(item)
                            .font(.custom("Manrope", size: 13))
                            .foregroundStyle(RecoveryPlanTeaserUI.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func roadmapBlurredContent(for phase: RecoveryPlanPhase) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(phase.summary)
                .font(.custom("Manrope", size: 14))
                .foregroundStyle(RecoveryPlanTeaserUI.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(roadmapLockedBullets(for: phase), id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(RecoveryPlanTeaserUI.rose)
                            .frame(width: 7, height: 7)
                            .padding(.top, 6)

                        Text(item)
                            .font(.custom("Manrope", size: 13))
                            .foregroundStyle(RecoveryPlanTeaserUI.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .blur(radius: 6)
        .opacity(0.72)
    }

    private var roadmapLockedOverlay: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.26), Color.white.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                VStack(spacing: 8) {
                    Text("Premium")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(RecoveryPlanTeaserUI.roseDeep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(RecoveryPlanTeaserUI.current.opacity(0.94))
                        )

                    Text("Unlock the rest of your roadmap")
                        .font(.custom("Manrope", size: 20).weight(.bold))
                        .foregroundStyle(RecoveryPlanTeaserUI.primaryInk)
                        .multilineTextAlignment(.center)

                    Text("See every upcoming phase from your real timeline forward.")
                        .font(.custom("Manrope", size: 13))
                        .foregroundStyle(RecoveryPlanTeaserUI.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                }
                .padding(20)
            }
    }

    private func roadmapSummary(for phase: RecoveryPlanPhase, access: PhaseAccess) -> String {
        switch access {
        case .full:
            return phase.summary.isEmpty
                ? "You are past the earliest recovery stage, so this roadmap starts here instead of replaying week one."
                : phase.summary
        case .locked:
            return phase.summary
        case .preview:
            return phase.summary
        }
    }

    private func roadmapBullets(for phase: RecoveryPlanPhase, access: PhaseAccess) -> [String] {
        switch access {
        case .full:
            let bullets = phase.focusAreas + phase.photoPrompts
            return Array(bullets.prefix(3))
        case .locked:
            return Array(roadmapLockedBullets(for: phase).prefix(3))
        case .preview:
            return Array(roadmapLockedBullets(for: phase).prefix(3))
        }
    }

    private func roadmapLockedBullets(for phase: RecoveryPlanPhase) -> [String] {
        let bullets = phase.focusAreas + phase.photoPrompts + phase.providerQuestions + phase.watchFors
        return Array(bullets.prefix(3))
    }
}

private enum PhaseAccess: Equatable {
    case full
    case preview
    case locked

    var label: String {
        switch self {
        case .full:
            return "Current phase"
        case .preview:
            return "Next phase"
        case .locked:
            return "Locked next"
        }
    }

    var labelColor: Color {
        switch self {
        case .full:
            return RecoveryPlanTeaserUI.roseDeep
        case .preview:
            return RecoveryPlanTeaserUI.primary
        case .locked:
            return RecoveryPlanTeaserUI.roseDeep
        }
    }

    var overlayTitle: String {
        switch self {
        case .full:
            return ""
        case .preview:
            return "Preview ends here"
        case .locked:
            return "Unlock the full plan"
        }
    }

    var overlayBody: String {
        switch self {
        case .full:
            return ""
        case .preview:
            return "See what comes next, then unlock the full step-by-step plan."
        case .locked:
            return "See every phase, what to watch, and what to ask next."
        }
    }

    var roadmapLabel: String {
        switch self {
        case .full:
            return "Current phase"
        case .preview:
            return "Next up"
        case .locked:
            return "Locked phase"
        }
    }

    func roadmapRangeText(for phase: RecoveryPlanPhase) -> String {
        switch self {
        case .full:
            return "You are here"
        case .preview:
            return "Preview"
        case .locked:
            if phase.weekStart == phase.weekEnd {
                return "Locked"
            }
            return "Locked"
        }
    }
}

#Preview {
    RecoveryPlanTeaserView(
        viewModel: previewRecoveryPlanViewModel,
        onUnlock: {}
    )
}

@MainActor
private var previewRecoveryPlanViewModel: RecoveryPlanViewModel {
    let vm = RecoveryPlanViewModel(isLocked: true)
    vm.plan = previewRecoveryPlan
    return vm
}

private var previewRecoveryPlan: PersonalizedRecoveryPlan {
    let phases = [
        RecoveryPlanPhase(
            id: "rhino-early-refinement",
            title: "Weeks 2-4: visible swelling starts to settle",
            weekStart: 2,
            weekEnd: 4,
            status: .current,
            summary: "You are no longer in the acute stage. This roadmap is focused on the weeks ahead, where trend comparison matters more than daily judgment.",
            expectations: [
                "Swelling can still move around from morning to evening.",
                "Small asymmetries often look louder than they are at this stage."
            ],
            focusAreas: [
                "Take consistent weekly photos instead of checking constantly.",
                "Track any patterns that feel persistent, not just surprising."
            ],
            photoPrompts: [
                "Capture front and profile photos in indirect light.",
                "Use the same angle and distance as last week."
            ],
            providerQuestions: [
                "What changes are realistic to expect by week six?",
                "Is the asymmetry I’m seeing typical for this stage?"
            ],
            watchFors: [
                "A swelling pattern that keeps worsening instead of gradually settling."
            ],
            encouragement: "You are already past the earliest phase, so this plan starts where your recovery actually is."
        ),
        RecoveryPlanPhase(
            id: "rhino-mid-refinement",
            title: "Weeks 5-8: compare trends, not daily changes",
            weekStart: 5,
            weekEnd: 8,
            status: .upcoming,
            summary: "This phase becomes more useful for week-to-week comparisons and more specific provider questions.",
            expectations: [
                "Subtle contour changes become easier to track in photos."
            ],
            focusAreas: [
                "Shift from emotional check-ins to structured comparisons."
            ],
            photoPrompts: [
                "Repeat your same front and profile capture set."
            ],
            providerQuestions: [
                "What should feel noticeably different by week eight?"
            ],
            watchFors: [
                "Persistent worsening tenderness or swelling."
            ],
            encouragement: "The next phase is more about trend clarity than instant transformation."
        ),
        RecoveryPlanPhase(
            id: "rhino-long-tail",
            title: "Months 3-12: gradual definition and long-tail refinement",
            weekStart: 9,
            weekEnd: 52,
            status: .upcoming,
            summary: "Long-tail refinement is where patience and milestone tracking matter most.",
            expectations: [
                "Final definition can take much longer than social media implies."
            ],
            focusAreas: [
                "Track major milestones, not tiny daily changes."
            ],
            photoPrompts: [
                "Capture one consistent monthly comparison set."
            ],
            providerQuestions: [
                "When should I evaluate my longer-term result more seriously?"
            ],
            watchFors: [
                "Changes that feel meaningfully worse rather than slowly refining."
            ],
            encouragement: "Later refinement often rewards patience more than constant checking."
        )
    ]

    return PersonalizedRecoveryPlan(
        id: UUID(),
        userId: UUID(),
        procedureName: "Rhinoplasty",
        procedureId: "rhinoplasty",
        procedureDate: Calendar.current.date(byAdding: .day, value: -21, to: Date()) ?? Date(),
        generatedAt: Date(),
        planVersion: 1,
        inputHash: "preview",
        currentPhase: phases[0],
        phases: phases,
        personalizationSummary: [
            "Anchored to weeks 2-4: visible swelling starts to settle",
            "Shaped around your goals: symmetry and refined profile",
            "Uses your logged recovery trend from 4 journal entries"
        ],
        disclaimers: [
            "This roadmap is educational and supportive. It is not a diagnosis."
        ]
    )
}
