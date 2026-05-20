//
//  RecoveryPlanView.swift
//  Renaissance Mobile
//

import SwiftUI

// MARK: – Design tokens
private enum R {
    static let bg      = Color(hex: "#F8F8FF")
    static let card    = Color.white
    static let ink     = Color(hex: "#2D2575")
    static let muted   = Color(hex: "#7B6FC0")
    static let primary = Color(hex: "#6C63FF")
    static let soft    = Color(hex: "#EAE7FF")
    static let line    = Color(hex: "#D4CCFF")
    static let shadow  = Color(hex: "#6C63FF").opacity(0.08)

    static func label(_ size: CGFloat) -> Font { .custom("PlusJakartaSans-SemiBold", size: size) }
    static func body(_ size: CGFloat)  -> Font { .custom("PlusJakartaSans-Regular",  size: size) }
    static func head(_ size: CGFloat)  -> Font { .custom("Manrope", size: size).weight(.bold) }
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
        let vm = viewModel ?? RecoveryPlanViewModel(isLocked: isLocked)
        vm.setLocked(isLocked)
        _viewModel = State(initialValue: vm)
        self.journalViewModel = journalViewModel
        self.onUpgrade = onUpgrade
    }

    @State private var expandedPhaseId: String? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                pageHeader

                if viewModel.isLoading && !viewModel.hasPlan {
                    loadingState
                } else if let plan = viewModel.plan {
                    procedureHeader(for: plan)
                    phaseList(for: plan)
                    if viewModel.isLocked { lockedFooterCard }
                } else if let error = viewModel.errorMessage {
                    errorCard(error)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 28) }
        .background(R.bg.ignoresSafeArea())
        .navigationTitle("Recovery Roadmap")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !viewModel.hasPlan, !viewModel.isLoading else { return }
            await viewModel.load(journalViewModel: journalViewModel)
            // Default: expand the current phase
            expandedPhaseId = viewModel.plan?.currentPhase.id
        }
    }

    // MARK: – Page header (replaces old badge + Canela heading card)

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.isLocked ? "YOUR RECOVERY ROADMAP" : "PERSONALIZED ROADMAP")
                .font(R.label(10))
                .tracking(2.4)
                .foregroundColor(R.primary)

            Text(viewModel.isLocked ? "Your recovery roadmap" : "Your personalized recovery roadmap")
                .font(R.head(26))
                .foregroundColor(R.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(
                viewModel.isLocked
                    ? "This roadmap starts at your current stage and shows the phases ahead. Unlock it to see the full sequence, watch-fors, and prompts."
                    : "Anchored to where your recovery is now, then guides the weeks and milestones still ahead."
            )
            .font(R.body(14))
            .foregroundColor(R.muted)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
    }

    // MARK: – Procedure header

    private func procedureHeader(for plan: PersonalizedRecoveryPlan) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.procedureName)
                    .font(R.label(15))
                    .foregroundColor(R.ink)
                Text("Week \(plan.currentPhase.weekStart) · \(plan.currentPhase.title)")
                    .font(R.body(12))
                    .foregroundColor(R.muted)
                    .lineLimit(1)
            }
            Spacer()
            Text("ACTIVE")
                .font(R.label(9))
                .tracking(1.6)
                .foregroundColor(R.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(R.soft)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(R.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(R.line.opacity(0.55), lineWidth: 1))
    }

    // MARK: – Phase list (compact collapsed cards)

    private func phaseList(for plan: PersonalizedRecoveryPlan) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(plan.phases.enumerated()), id: \.element.id) { index, phase in
                let acc = access(for: phase, index: index, plan: plan)
                let isExpanded = expandedPhaseId == phase.id

                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        expandedPhaseId = isExpanded ? nil : phase.id
                    }
                } label: {
                    phaseCard(phase, access: acc, isExpanded: isExpanded)
                }
                .buttonStyle(.plain)
                .disabled(acc == .locked)
            }
        }
    }

    private func phaseCard(_ phase: RecoveryPlanPhase, access: RecoveryPlanPhaseAccess, isExpanded: Bool) -> some View {
        let isCurrent   = phase.status == .current
        let isPast      = phase.status == .completed

        return VStack(alignment: .leading, spacing: 0) {
            // — Collapsed header row
            HStack(alignment: .center, spacing: 12) {
                // Status dot
                Circle()
                    .fill(isCurrent ? R.primary : (isPast ? R.line : R.line.opacity(0.5)))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(weekBadge(for: phase))
                        .font(R.label(10))
                        .tracking(0.8)
                        .foregroundColor(isCurrent ? R.primary : R.muted)
                    Text(phase.title)
                        .font(R.label(14))
                        .foregroundColor(isCurrent ? R.ink : (isPast ? R.muted : R.ink.opacity(0.7)))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if access == .locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(R.line)
                } else {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(R.muted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // — Expanded detail
            if isExpanded && access != .locked {
                VStack(alignment: .leading, spacing: 14) {
                    Divider().background(R.line)

                    Text(phase.summary)
                        .font(R.body(13))
                        .foregroundColor(R.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)

                    if !phase.focusAreas.isEmpty {
                        timelineSection(title: "FOCUS AREAS", items: Array(phase.focusAreas.prefix(3)), locked: false)
                            .padding(.horizontal, 16)
                    }

                    if !phase.watchFors.isEmpty {
                        timelineSection(title: "WATCH FORS", items: Array(phase.watchFors.prefix(2)), locked: false)
                            .padding(.horizontal, 16)
                    }

                    if !phase.photoPrompts.isEmpty {
                        timelineSection(title: "PHOTO PROMPTS", items: Array(phase.photoPrompts.prefix(2)), locked: false)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isCurrent ? R.soft.opacity(0.45) : R.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isCurrent ? R.primary.opacity(0.2) : R.line.opacity(0.55), lineWidth: isCurrent ? 1.5 : 1)
        )
        .shadow(color: R.shadow.opacity(isCurrent ? 1 : 0.4), radius: 8, x: 0, y: 3)
    }

    private func weekBadge(for phase: RecoveryPlanPhase) -> String {
        if phase.weekStart == 1 && phase.weekEnd == 1 { return "WEEK 1" }
        if phase.weekStart == phase.weekEnd { return "WEEK \(phase.weekStart)" }
        return "WEEKS \(phase.weekStart)–\(phase.weekEnd)"
    }

    // MARK: – Context strip (replaces stat chips) — kept for reference, unused

    private func contextStrip(for plan: PersonalizedRecoveryPlan) -> some View {
        HStack(spacing: 0) {
            contextCell(title: "Current phase", value: plan.currentPhase.title)

            Divider()
                .background(R.line)
                .padding(.vertical, 10)

            contextCell(title: "Procedure", value: plan.procedureName)
        }
        .background(R.soft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func contextCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(R.label(10))
                .tracking(0.8)
                .foregroundColor(R.muted)
            Text(value)
                .font(R.label(13))
                .foregroundColor(R.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: – Current focus card

    private func currentFocusCard(for plan: PersonalizedRecoveryPlan) -> some View {
        let phase = plan.currentPhase

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    cardEyebrow("WHAT MATTERS NOW")
                    Text(phase.title)
                        .font(R.head(22))
                        .foregroundColor(R.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text("Week \(phase.weekStart)")
                    .font(R.label(11))
                    .foregroundColor(R.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.75))
                    .clipShape(Capsule())
            }

            Text(phase.summary)
                .font(R.body(14))
                .foregroundColor(R.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if !phase.focusAreas.isEmpty        { timelineSection(title: "FOCUS AREAS",                 items: phase.focusAreas,          locked: false) }
            if !phase.photoPrompts.isEmpty       { timelineSection(title: "PHOTO PROMPTS",               items: phase.photoPrompts,         locked: false) }
            if !phase.providerQuestions.isEmpty  { timelineSection(title: "QUESTIONS FOR YOUR PROVIDER", items: phase.providerQuestions,    locked: false) }

            if let note = phase.encouragement {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(R.primary)
                        .frame(width: 3)
                    Text(note)
                        .font(R.body(13))
                        .foregroundColor(R.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(R.soft.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card(tint: R.soft.opacity(0.55)))
    }

    // MARK: – Roadmap card

    private func roadmapCard(for plan: PersonalizedRecoveryPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                cardEyebrow("PHASES AHEAD")
                Text("The phases ahead")
                    .font(R.head(22))
                    .foregroundColor(R.ink)
            }

            Text(
                viewModel.isLocked
                    ? "Preview the next phase — unlock premium to see the full sequence."
                    : "Each phase is arranged from your real timeline forward."
            )
            .font(R.body(14))
            .foregroundColor(R.muted)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                ForEach(Array(plan.phases.enumerated()), id: \.element.id) { index, phase in
                    phaseRow(phase, access: access(for: phase, index: index, plan: plan))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card())
    }

    private func phaseRow(_ phase: RecoveryPlanPhase, access: RecoveryPlanPhaseAccess) -> some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let lbl = access.label {
                            Text(lbl.uppercased())
                                .font(R.label(9))
                                .tracking(1.4)
                                .foregroundColor(access.color)
                        }
                        Text(phase.title)
                            .font(R.head(18))
                            .foregroundColor(R.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Text(phase.weekStart == phase.weekEnd
                         ? "Week \(phase.weekStart)"
                         : "Wks \(phase.weekStart)–\(phase.weekEnd)")
                        .font(R.label(10))
                        .foregroundColor(R.muted)
                }

                Text(phase.summary)
                    .font(R.body(13))
                    .foregroundColor(R.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !phase.expectations.isEmpty { timelineSection(title: "EXPECTATIONS", items: phase.expectations, locked: access != .full) }
                if !phase.watchFors.isEmpty     { timelineSection(title: "WATCH FORS",  items: phase.watchFors,    locked: access == .locked) }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(LockedContentModifier(access: access))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(phase.status == .current ? R.soft.opacity(0.55) : R.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(R.line.opacity(0.6), lineWidth: 1)
            )

            if access != .full {
                lockOverlay(access: access)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func lockOverlay(access: RecoveryPlanPhaseAccess) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(R.primary)
                    .frame(width: 36, height: 36)
                Image(systemName: access == .preview ? "eye" : "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(access == .preview ? "Preview ends here" : "Premium roadmap")
                .font(R.head(16))
                .foregroundColor(R.ink)

            Text(access == .preview
                 ? "Full prompts and watch-fors unlock with premium."
                 : "Unlock your full timeline, watch-fors, and provider prompts.")
                .font(R.body(12))
                .foregroundColor(R.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 220)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [R.card.opacity(0.1), R.card.opacity(0.88)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    // MARK: – Disclaimers

    private func disclaimersCard(for plan: PersonalizedRecoveryPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            cardEyebrow("IMPORTANT CONTEXT")
            Text("Important context")
                .font(R.head(20))
                .foregroundColor(R.ink)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(plan.disclaimers, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(R.primary)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(item)
                            .font(R.body(13))
                            .foregroundColor(R.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card())
    }

    // MARK: – Locked footer

    private var lockedFooterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardEyebrow("PREMIUM FEATURE")
            Text("Unlock the full roadmap")
                .font(R.head(22))
                .foregroundColor(R.ink)

            Text("Get every upcoming phase, your full watch list, personalized photo prompts, and smarter follow-up questions based on your timeline.")
                .font(R.body(14))
                .foregroundColor(R.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let onUpgrade {
                Button(action: onUpgrade) {
                    Text("Unlock Premium")
                        .font(R.label(15))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(R.primary)
                        .clipShape(Capsule())
                        .shadow(color: R.primary.opacity(0.3), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card())
    }

    // MARK: – States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(i == 0 ? R.soft.opacity(0.55) : R.card)
                    .frame(height: i == 0 ? 200 : 170)
                    .redacted(reason: .placeholder)
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("We need a bit more context")
                .font(R.head(20))
                .foregroundColor(R.ink)

            Text(message)
                .font(R.body(14))
                .foregroundColor(R.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await viewModel.refresh(journalViewModel: journalViewModel) }
            } label: {
                Text("Try again")
                    .font(R.label(15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(R.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card())
    }

    // MARK: – Shared components

    private func cardEyebrow(_ text: String) -> some View {
        Text(text)
            .font(R.label(9))
            .tracking(2)
            .foregroundColor(R.primary)
    }

    // Timeline section — uses left-border row style from the mockup
    private func timelineSection(title: String, items: [String], locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(R.label(9))
                .tracking(1.8)
                .foregroundColor(R.muted)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(items.prefix(locked ? 1 : 4), id: \.self) { item in
                    HStack(alignment: .top, spacing: 0) {
                        // Left border accent
                        Rectangle()
                            .fill(R.line)
                            .frame(width: 2)
                            .padding(.vertical, 2)

                        Text(item)
                            .font(R.body(13))
                            .foregroundColor(R.ink)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 12)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    private func card(tint: Color = R.card) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(tint)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(R.line.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: R.shadow, radius: 12, x: 0, y: 4)
    }

    // MARK: – Access logic

    private func access(
        for phase: RecoveryPlanPhase,
        index: Int,
        plan: PersonalizedRecoveryPlan
    ) -> RecoveryPlanPhaseAccess {
        guard viewModel.isLocked else { return .full }
        if phase.status == .current { return .full }
        let upcomingIndices = plan.phases.enumerated().compactMap { e in
            e.element.status == .upcoming ? e.offset : nil
        }
        return upcomingIndices.first == index ? .preview : .locked
    }
}

// MARK: – Supporting types

private enum RecoveryPlanPhaseAccess: Equatable {
    case full, preview, locked

    var label: String? {
        switch self {
        case .full:    return nil
        case .preview: return "Preview"
        case .locked:  return "Premium"
        }
    }

    var color: Color {
        switch self {
        case .full, .locked: return Color(hex: "#6C63FF")
        case .preview:       return Color(hex: "#7B6FC0")
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
                LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom)
            )
        case .locked:
            content.blur(radius: 5).opacity(0.38)
        }
    }
}

#Preview {
    NavigationStack {
        RecoveryPlanView(isLocked: false)
    }
}
