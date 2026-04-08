//
//  RecoveryPlanView.swift
//  Renaissance Mobile
//

import SwiftUI

private enum RecoveryPlanViewUI {
    static let bg = Color(hex: "#F6F7F2")
    static let card = Color.white.opacity(0.90)
    static let soft = Color(hex: "#EDF1E8")
    static let softStrong = Color(hex: "#D9E3CE")
    static let roseSoft = Color(hex: "#F1DDDA")
    static let rose = Color(hex: "#B07B7A")
    static let roseDeep = Color(hex: "#976769")
    static let text = Color(hex: "#1F261D")
    static let muted = Color(hex: "#687064")
    static let primary = Color(hex: "#516048")
    static let primaryInk = Color(hex: "#314030")
    static let line = Color.black.opacity(0.06)
    static let shadow = Color(red: 90/255, green: 103/255, blue: 80/255).opacity(0.10)
}

struct RecoveryPlanView: View {
    @State private var viewModel: RecoveryPlanViewModel

    private let journalViewModel: JournalViewModel?
    private let onUpgrade: (() -> Void)?

    @MainActor
    init(
        viewModel: RecoveryPlanViewModel? = nil,
        journalViewModel: JournalViewModel? = nil,
        isLocked: Bool,
        onUpgrade: (() -> Void)? = nil
    ) {
        let resolvedViewModel = viewModel ?? RecoveryPlanViewModel(isLocked: isLocked)
        resolvedViewModel.setLocked(isLocked)
        _viewModel = State(initialValue: resolvedViewModel)
        self.journalViewModel = journalViewModel
        self.onUpgrade = onUpgrade
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                headerCard

                if viewModel.isLoading && !viewModel.hasPlan {
                    loadingState
                } else if let plan = viewModel.plan {
                    summaryRow(for: plan)
                    currentFocusCard(for: plan)
                    roadmapCard(for: plan)
                    disclaimersCard(for: plan)

                    if viewModel.isLocked {
                        lockedFooterCard
                    }
                } else if let error = viewModel.errorMessage {
                    errorCard(error)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 34)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 28)
        }
        .background(background.ignoresSafeArea())
        .navigationTitle("Recovery Roadmap")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !viewModel.hasPlan, !viewModel.isLoading else { return }
            await viewModel.load(journalViewModel: journalViewModel)
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#F8FAF4"), RecoveryPlanViewUI.bg],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(RecoveryPlanViewUI.rose.opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 28)
                .offset(x: 120, y: -240)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(viewModel.isLocked ? "Premium feature" : "Personalized plan", systemImage: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(RecoveryPlanViewUI.roseDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(RecoveryPlanViewUI.roseSoft))

            Text(viewModel.isLocked ? "Your recovery roadmap" : "Your personalized recovery roadmap")
                .font(.custom("Canela", size: 34))
                .foregroundStyle(RecoveryPlanViewUI.text)

            Text(
                viewModel.isLocked
                ? "This roadmap starts at your current stage and shows the next phases ahead. Unlock it to see the full sequence, watch-fors, and follow-up prompts."
                : "This roadmap is anchored to where your recovery actually is now, then guides the weeks and milestones still ahead."
            )
            .font(.custom("Manrope", size: 15))
            .foregroundStyle(RecoveryPlanViewUI.muted)
            .lineSpacing(3)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private func summaryRow(for plan: PersonalizedRecoveryPlan) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                statChip(title: "Current phase", value: plan.currentPhase.title)
                statChip(title: "Procedure", value: plan.procedureName)

                ForEach(plan.personalizationSummary.prefix(2), id: \.self) { item in
                    statChip(title: "Personalized", value: item)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func currentFocusCard(for plan: PersonalizedRecoveryPlan) -> some View {
        let phase = plan.currentPhase

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What matters now")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(RecoveryPlanViewUI.roseDeep)

                    Text(phase.title)
                        .font(.custom("Manrope", size: 24))
                        .foregroundStyle(RecoveryPlanViewUI.text)
                }

                Spacer()

                Text("Week \(phase.weekStart)")
                    .font(.custom("Manrope", size: 12))
                    .foregroundStyle(RecoveryPlanViewUI.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.84)))
            }

            Text(phase.summary)
                .font(.custom("Manrope", size: 14))
                .foregroundStyle(RecoveryPlanViewUI.muted)
                .lineSpacing(3)

            planSection(title: "Focus areas", items: phase.focusAreas, locked: false)
            planSection(title: "Photo prompts", items: phase.photoPrompts, locked: false)
            planSection(title: "Questions for your provider", items: phase.providerQuestions, locked: false)

            if let encouragement = phase.encouragement {
                Text(encouragement)
                    .font(.custom("Manrope", size: 13))
                    .foregroundStyle(RecoveryPlanViewUI.primaryInk)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(RecoveryPlanViewUI.softStrong.opacity(0.85))
                    )
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(fill: RecoveryPlanViewUI.roseSoft.opacity(0.72)))
    }

    private func roadmapCard(for plan: PersonalizedRecoveryPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("The phases ahead")
                .font(.custom("Manrope", size: 24))
                .foregroundStyle(RecoveryPlanViewUI.text)

            Text(
                viewModel.isLocked
                ? "You can preview the immediate next phase, but the deeper roadmap is reserved for premium."
                : "Each phase below is already arranged from your real timeline forward."
            )
            .font(.custom("Manrope", size: 14))
            .foregroundStyle(RecoveryPlanViewUI.muted)
            .lineSpacing(3)

            VStack(spacing: 14) {
                ForEach(Array(plan.phases.enumerated()), id: \.element.id) { index, phase in
                    roadmapPhaseCard(phase, access: access(for: phase, index: index, plan: plan))
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private func roadmapPhaseCard(_ phase: RecoveryPlanPhase, access: RecoveryPlanPhaseAccess) -> some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let label = access.label {
                            Text(label)
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.4)
                                .foregroundStyle(access.color)
                        }

                        Text(phase.title)
                            .font(.custom("Manrope", size: 20))
                            .foregroundStyle(RecoveryPlanViewUI.text)
                    }

                    Spacer()

                    Text(phase.weekStart == phase.weekEnd ? "Week \(phase.weekStart)" : "Weeks \(phase.weekStart)-\(phase.weekEnd)")
                        .font(.custom("Manrope", size: 12))
                        .foregroundStyle(RecoveryPlanViewUI.muted)
                }

                Text(phase.summary)
                    .font(.custom("Manrope", size: 14))
                    .foregroundStyle(RecoveryPlanViewUI.muted)
                    .lineSpacing(3)

                planSection(title: "Expectations", items: phase.expectations, locked: access != .full)
                planSection(title: "Watch fors", items: phase.watchFors, locked: access == .locked)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(LockedContentModifier(access: access))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(phase.status == .current ? RecoveryPlanViewUI.roseSoft.opacity(0.72) : Color.white.opacity(0.84))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(RecoveryPlanViewUI.line, lineWidth: 1)
            )

            if access != .full {
                VStack(spacing: 8) {
                    Image(systemName: access == .preview ? "eye" : "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(RecoveryPlanViewUI.primaryInk)

                    Text(access == .preview ? "Preview ends here" : "Premium roadmap")
                        .font(.custom("Manrope", size: 16))
                        .foregroundStyle(RecoveryPlanViewUI.text)

                    Text(
                        access == .preview
                        ? "The next phase is partially visible, but the full prompts and watch-list unlock with premium."
                        : "Unlock the rest of your timeline, watch-fors, and provider prompts."
                    )
                    .font(.custom("Manrope", size: 13))
                    .foregroundStyle(RecoveryPlanViewUI.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 250)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
            }
        }
    }

    private func disclaimersCard(for plan: PersonalizedRecoveryPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Important context")
                .font(.custom("Manrope", size: 22))
                .foregroundStyle(RecoveryPlanViewUI.text)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(plan.disclaimers, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(RecoveryPlanViewUI.roseDeep)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(item)
                            .font(.custom("Manrope", size: 13))
                            .foregroundStyle(RecoveryPlanViewUI.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private var lockedFooterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Unlock the full roadmap")
                .font(.custom("Manrope", size: 24))
                .foregroundStyle(RecoveryPlanViewUI.text)

            Text("Get every upcoming phase, your full watch list, personalized photo prompts, and smarter follow-up questions based on your timeline.")
                .font(.custom("Manrope", size: 14))
                .foregroundStyle(RecoveryPlanViewUI.muted)
                .lineSpacing(3)

            if let onUpgrade {
                Button(action: onUpgrade) {
                    Text("Unlock Premium")
                        .font(.custom("Manrope", size: 16).weight(.semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(RecoveryPlanViewUI.primary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(index == 0 ? RecoveryPlanViewUI.roseSoft.opacity(0.65) : Color.white.opacity(0.75))
                    .frame(height: index == 0 ? 220 : 180)
                    .redacted(reason: .placeholder)
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("We need a little more recovery context")
                .font(.custom("Manrope", size: 22))
                .foregroundStyle(RecoveryPlanViewUI.text)

            Text(message)
                .font(.custom("Manrope", size: 14))
                .foregroundStyle(RecoveryPlanViewUI.muted)
                .lineSpacing(3)

            Button {
                Task { await viewModel.refresh(journalViewModel: journalViewModel) }
            } label: {
                Text("Try again")
                    .font(.custom("Manrope", size: 15).weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(RecoveryPlanViewUI.primary)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(RecoveryPlanViewUI.roseDeep)
            Text(value)
                .font(.custom("Manrope", size: 12).weight(.semibold))
                .foregroundStyle(RecoveryPlanViewUI.primaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RecoveryPlanViewUI.soft)
        )
    }

    private func planSection(title: String, items: [String], locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(RecoveryPlanViewUI.roseDeep)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.prefix(locked ? 1 : 3), id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(RecoveryPlanViewUI.primary)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(item)
                            .font(.custom("Manrope", size: 13))
                            .foregroundStyle(RecoveryPlanViewUI.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func access(
        for phase: RecoveryPlanPhase,
        index: Int,
        plan: PersonalizedRecoveryPlan
    ) -> RecoveryPlanPhaseAccess {
        guard viewModel.isLocked else { return .full }
        if phase.status == .current { return .full }

        let upcomingIndices = plan.phases.enumerated().compactMap { element in
            element.element.status == .upcoming ? element.offset : nil
        }
        if upcomingIndices.first == index { return .preview }
        return .locked
    }

    private func cardBackground(fill: Color = RecoveryPlanViewUI.card) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(RecoveryPlanViewUI.line, lineWidth: 1)
            )
            .shadow(color: RecoveryPlanViewUI.shadow, radius: 20, x: 0, y: 10)
    }
}

private enum RecoveryPlanPhaseAccess: Equatable {
    case full
    case preview
    case locked

    var label: String? {
        switch self {
        case .full: return nil
        case .preview: return "Preview"
        case .locked: return "Premium feature"
        }
    }

    var color: Color {
        switch self {
        case .full: return RecoveryPlanViewUI.roseDeep
        case .preview: return RecoveryPlanViewUI.primary
        case .locked: return RecoveryPlanViewUI.roseDeep
        }
    }
}

private struct LockedContentModifier: ViewModifier {
    let access: RecoveryPlanPhaseAccess

    func body(content: Content) -> some View {
        switch access {
        case .full:
            content
        case .preview:
            content.mask(
                LinearGradient(
                    colors: [.black, .black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .locked:
            content
                .blur(radius: 6)
                .opacity(0.42)
        }
    }
}

#Preview {
    NavigationStack {
        RecoveryPlanView(isLocked: false)
    }
}
