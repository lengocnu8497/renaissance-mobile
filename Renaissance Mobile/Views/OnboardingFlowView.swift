//
//  OnboardingFlowView.swift
//  Renaissance Mobile
//

import SwiftUI
import StoreKit

// MARK: - Design tokens

private enum OnboardingUI {
    static let shell      = Color(hex: "#EEEEFF")
    static let bg         = Color(hex: "#FAFAFF")
    static let surface    = Color(hex: "#F5F4FF")
    static let card       = Color(hex: "#EDEAFF")
    static let text       = Color(hex: "#1E1B4B")
    static let muted      = Color(hex: "#7B6FC0")
    static let primary    = Color(hex: "#6C63FF")
    static let primaryInk = Color(hex: "#2D2575")
    static let primarySoft = Color(hex: "#D4CCFF")
    static let rose       = Color(hex: "#8B7FF0")
    static let roseSoft   = Color(hex: "#EAE7FF")
    static let roseTint   = Color(hex: "#E0DBFF")
    static let roseDeep   = Color(hex: "#5B50D6")
    static let shadow     = Color(red: 70/255, green: 60/255, blue: 180/255).opacity(0.08)
}

// MARK: - Screen + Branch enums

private enum OnboardingScreen: Equatable {
    case welcome
    case branchSelection
    // Researching path
    case researchProcedure
    case researchStage
    case researchNeeds
    // Planning path
    case planProcedure
    case planConsultation
    case planHealth
    case planTimeline
    // Recovering path
    case recoverProcedure
    case recoverTiming
    case recoverHealth
    case recoverEmotion
    // Convergence
    case personalizedTeaser
    case softPitch
    case paywall
    case discountOffer
}

enum OnboardingBranch: String, Equatable {
    case researching
    case planning
    case recovering
}

// MARK: - Procedure options (used in recovering + planning paths)

private enum ProcedureOption: String, CaseIterable, Identifiable {
    case rhinoplasty    = "Rhinoplasty"
    case breastSurgery  = "Breast Surgery"
    case bodyContouring = "Body Contouring"
    case facialSurgery  = "Facial Surgery"
    case other          = "Multiple / Other"

    var id: String { rawValue }

    var storedName: String {
        switch self {
        case .rhinoplasty:    return "Rhinoplasty"
        case .breastSurgery:  return "Breast Surgery"
        case .bodyContouring: return "Body Contouring"
        case .facialSurgery:  return "Facial Surgery"
        case .other:          return "Surgery"
        }
    }

    var icon: String {
        switch self {
        case .rhinoplasty:    return "scissors"
        case .breastSurgery:  return "heart.fill"
        case .bodyContouring: return "figure.stand"
        case .facialSurgery:  return "eye.fill"
        case .other:          return "plus"
        }
    }

    var optionDescription: String {
        switch self {
        case .rhinoplasty:    return "Nose reshaping, tip refinement, septoplasty"
        case .breastSurgery:  return "Augmentation, reduction or lift"
        case .bodyContouring: return "Liposuction, tummy tuck, BBL"
        case .facialSurgery:  return "Facelift, eyelid lift, brow lift"
        case .other:          return "Combination or another surgical procedure"
        }
    }
}

// MARK: - Timing options (recovering path)

private enum WhenOption: String, CaseIterable, Identifiable {
    case oneToThreeDays    = "1–3 days ago"
    case fourToSevenDays   = "4–7 days ago"
    case oneToTwoWeeks     = "1–2 weeks ago"
    case twoToSixWeeks     = "2–6 weeks ago"
    case sixWeeksToThreeMo = "6 weeks – 3 months ago"
    case threeMonthsPlus   = "3+ months ago"

    var id: String { rawValue }

    var procedureDate: Date {
        let cal = Calendar.current
        let daysBack: Int
        switch self {
        case .oneToThreeDays:    daysBack = 2
        case .fourToSevenDays:   daysBack = 5
        case .oneToTwoWeeks:     daysBack = 10
        case .twoToSixWeeks:     daysBack = 28
        case .sixWeeksToThreeMo: daysBack = 63
        case .threeMonthsPlus:   daysBack = 120
        }
        return cal.date(byAdding: .day, value: -daysBack, to: cal.startOfDay(for: Date())) ?? Date()
    }
}

// MARK: - ChipFlowLayout

private struct ChipFlowLayout: Layout {
    var itemSpacing: CGFloat = 8
    var rowSpacing: CGFloat  = 8

    private func measuredSize(for subview: LayoutSubview, availableWidth: CGFloat) -> CGSize {
        let unconstrained = subview.sizeThatFits(.unspecified)
        let fitted = min(unconstrained.width, availableWidth)
        return subview.sizeThatFits(ProposedViewSize(width: fitted, height: nil))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? UIScreen.main.bounds.width - 72
        var x: CGFloat = 0; var rowH: CGFloat = 0; var totalH: CGFloat = 0
        for sv in subviews {
            let s = measuredSize(for: sv, availableWidth: maxW)
            let sp = x > 0 ? itemSpacing : 0
            if x > 0, x + sp + s.width > maxW { totalH += rowH + rowSpacing; x = 0; rowH = 0 }
            rowH = max(rowH, s.height); x += s.width + sp
        }
        return CGSize(width: maxW, height: totalH + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for sv in subviews {
            let s = measuredSize(for: sv, availableWidth: bounds.width)
            let sp = x > bounds.minX ? itemSpacing : 0
            if x > bounds.minX, x + sp + s.width > bounds.maxX { x = bounds.minX; y += rowH + rowSpacing; rowH = 0 }
            sv.place(at: CGPoint(x: x + sp, y: y), proposal: ProposedViewSize(width: s.width, height: s.height))
            x += s.width + sp; rowH = max(rowH, s.height)
        }
    }
}

// MARK: - OnboardingFlowView

struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    var onboardingSessionID: UUID = UUID()
    var onFinish: () -> Void = {}

    private enum ActiveAlert: Identifiable, Equatable {
        case onboardingReviewPrompt
        case reviewUnavailable(String)
        var id: String {
            switch self {
            case .onboardingReviewPrompt: return "review-prompt"
            case .reviewUnavailable(let m): return "review-unavailable-\(m)"
            }
        }
    }

    // Navigation
    @State private var currentScreen: OnboardingScreen = .welcome
    @State private var navHistory: [OnboardingScreen] = []

    // Branch
    @State private var selectedBranch: OnboardingBranch? = nil

    // Recovering path state
    @State private var recoverProcedures: Set<ProcedureOption> = []
    @State private var recoverWhen: WhenOption? = nil
    @State private var recoverHealthFlags: Set<String> = []
    @State private var recoverEmotion: String? = nil

    // Planning path state
    @State private var planProcedure: ProcedureOption? = nil
    @State private var planConsultation: String? = nil
    @State private var planHealthFlags: Set<String> = []
    @State private var planTimeline: String? = nil

    // Researching path state
    @State private var researchProcedures: Set<String> = []
    @State private var researchBodyAreas: Set<String> = []
    @State private var researchStage: String? = nil
    @State private var researchNeeds: Set<String> = []

    // Teaser
    @State private var teaserViewModel = OnboardingTeaserViewModel()
    @State private var didQueueReviewPrompt = false
    @State private var activeAlert: ActiveAlert?
    @State private var isCompletingOnboarding = false

    private let userProfileService = UserProfileService(supabase: supabase)
    private let recoveryPlanService = RecoveryPlanService()
    private let stickyBottomPadding: CGFloat = 112

    var body: some View {
        ZStack {
            shellBackground.ignoresSafeArea()
            Group {
                switch currentScreen {
                case .welcome:            welcomeScreen
                case .branchSelection:    branchSelectionScreen
                case .researchProcedure:  researchProcedureScreen
                case .researchStage:      researchStageScreen
                case .researchNeeds:      researchNeedsScreen
                case .planProcedure:      planProcedureScreen
                case .planConsultation:   planConsultationScreen
                case .planHealth:         planHealthScreen
                case .planTimeline:       planTimelineScreen
                case .recoverProcedure:   recoverProcedureScreen
                case .recoverTiming:      recoverTimingScreen
                case .recoverHealth:      recoverHealthScreen
                case .recoverEmotion:     recoverEmotionScreen
                case .personalizedTeaser: personalizedTeaserScreen
                case .softPitch:          softPitchScreen
                case .paywall:            paywallScreen
                case .discountOffer:      discountOfferScreen
                }
            }
            .id(currentScreen)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.28), value: currentScreen)
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .onboardingReviewPrompt:
                return Alert(
                    title: Text("How do you like Rena so far?"),
                    message: Text("If the recovery plan feels helpful, Apple may show a quick rating prompt."),
                    primaryButton: .default(Text("Leave a Rating")) {
                        Task { @MainActor in await requestOnboardingReview() }
                    },
                    secondaryButton: .cancel(Text("Not Now"))
                )
            case .reviewUnavailable(let message):
                return Alert(
                    title: Text("Rating Unavailable"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Navigation helpers

    private func push(_ screen: OnboardingScreen) {
        navHistory.append(currentScreen)
        withAnimation(.easeInOut(duration: 0.28)) { currentScreen = screen }
    }

    private func pop() {
        guard let previous = navHistory.popLast() else { return }
        withAnimation(.easeInOut(duration: 0.28)) { currentScreen = previous }
    }

    // MARK: - Progress

    private var branchProgress: (step: Int, total: Int)? {
        switch selectedBranch {
        case .researching:
            switch currentScreen {
            case .researchProcedure: return (1, 3)
            case .researchStage:     return (2, 3)
            case .researchNeeds:     return (3, 3)
            default: return nil
            }
        case .planning:
            switch currentScreen {
            case .planProcedure:    return (1, 4)
            case .planConsultation: return (2, 4)
            case .planHealth:       return (3, 4)
            case .planTimeline:     return (4, 4)
            default: return nil
            }
        case .recovering:
            switch currentScreen {
            case .recoverProcedure: return (1, 4)
            case .recoverTiming:    return (2, 4)
            case .recoverHealth:    return (3, 4)
            case .recoverEmotion:   return (4, 4)
            default: return nil
            }
        case .none:
            return nil
        }
    }

    // MARK: - Background

    private var shellBackground: some View {
        ZStack {
            LinearGradient(
                colors: [OnboardingUI.bg, OnboardingUI.shell],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [OnboardingUI.primary.opacity(0.07), .clear],
                center: .top, startRadius: 0, endRadius: 280
            )
        }
    }

    // MARK: - Welcome Screen

    private var welcomeScreen: some View {
        VStack(spacing: 0) {
            // Title block — fixed at top
            VStack(alignment: .leading, spacing: 8) {
                Text("Hi, I'm Rena.")
                    .font(Theme.Manrope.bold(42))
                    .foregroundColor(OnboardingUI.primaryInk)

                Text("Your guide through every part of the aesthetic journey.")
                    .font(Theme.Manrope.extraBold(18))
                    .foregroundColor(OnboardingUI.primary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 64)

            // Animation fills all remaining space; scaleEffect compensates
            // for the canvas whitespace in the Lottie file so Rena appears large
            LottieView(name: "rena-lottie")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(1.65)
                .clipped()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Analytics.onboardingStarted()
                push(.branchSelection)
            } label: {
                Text("Let's go")
                    .font(Theme.PlusJakartaSans.semiBold(16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.black)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
            .padding(.top, 8)
            .background(OnboardingUI.bg)
        }
    }

    // MARK: - Personalize Transition Screen

    private func renaLogoMark(size: CGFloat, color: Color) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.5), lineWidth: 1.5)
                .frame(width: size, height: size)
            Circle()
                .stroke(color.opacity(0.75), lineWidth: 1.2)
                .frame(width: size * 0.74, height: size * 0.74)
            Circle()
                .stroke(color, lineWidth: 1.5)
                .frame(width: size * 0.47, height: size * 0.47)
            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(color.opacity(0.65), lineWidth: 1.2)
                .frame(width: size * 0.74, height: size * 0.74)
                .rotationEffect(.degrees(90))
            Circle()
                .fill(color)
                .frame(width: size * 0.1, height: size * 0.1)
        }
    }

    // MARK: - Branch Selection Screen

    private var branchSelectionScreen: some View {
        VStack(spacing: 0) {
            backButton { pop() }

            ScrollView(showsIndicators: false) {
                screenCard {
                    introBlock(eyebrow: "Your journey", title: "Let's personalize your experience", body: "Wherever you are in your journey, Rena tailors everything to you.")

                    VStack(spacing: 12) {
                        branchCard(
                            branch: .researching,
                            label: "Just researching",
                            sub: "I'm exploring options, not committed yet",
                            icon: "magnifyingglass"
                        ) {
                            selectedBranch = .researching
                            Analytics.onboardingBranchSelected(.researching)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { push(.researchProcedure) }
                        }
                        branchCard(
                            branch: .planning,
                            label: "Planning a procedure",
                            sub: "I have something in mind or coming up",
                            icon: "calendar.badge.plus"
                        ) {
                            selectedBranch = .planning
                            Analytics.onboardingBranchSelected(.planning)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { push(.planProcedure) }
                        }
                        branchCard(
                            branch: .recovering,
                            label: "Recovering",
                            sub: "I've already had something done",
                            icon: "waveform.path.ecg"
                        ) {
                            selectedBranch = .recovering
                            Analytics.onboardingBranchSelected(.recovering)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { push(.recoverProcedure) }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func branchCard(branch: OnboardingBranch, label: String, sub: String, icon: String, action: @escaping () -> Void) -> some View {
        let isSelected = selectedBranch == branch
        return Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? OnboardingUI.roseSoft.opacity(0.9) : OnboardingUI.card)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? OnboardingUI.roseDeep : OnboardingUI.muted)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                        .foregroundColor(OnboardingUI.primaryInk)
                    Text(sub)
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundColor(OnboardingUI.muted)
                        .lineSpacing(2)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? OnboardingUI.primary : OnboardingUI.muted.opacity(0.35))
            }
            .padding(16)
            .background(isSelected ? OnboardingUI.roseSoft.opacity(0.45) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? OnboardingUI.rose.opacity(0.42) : Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Researching Path

    private var researchProcedureScreen: some View {
        VStack(spacing: 0) {
            progressBar(step: 1, total: 3)

            ScrollView(showsIndicators: false) {
                screenCard {
                    introBlock(eyebrow: "Step 1 of 3", title: "What's catching your interest?", body: "Select everything you're curious about — no commitment.")

                    VStack(alignment: .leading, spacing: 18) {
                        contextSection(title: "Procedures") {
                            chipGrid(
                                options: ProfileSelectionCatalog.procedureOptions,
                                selected: Array(researchProcedures),
                                multiSelect: true
                            ) { val in
                                toggle(&researchProcedures, val)
                            }
                        }
                        contextSection(title: "Body areas") {
                            chipGrid(
                                options: ProfileSelectionCatalog.bodyAreaOptions,
                                selected: Array(researchBodyAreas),
                                multiSelect: true
                            ) { val in
                                toggle(&researchBodyAreas, val)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, stickyBottomPadding)
            }
        }
        .safeAreaInset(edge: .bottom) {
            blendedCTA {
                primaryButton(label: "Continue", enabled: !researchProcedures.isEmpty) {
                    Analytics.onboardingStepCompleted(stepName: "research_procedure", branch: .researching)
                    push(.researchStage)
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var researchStageScreen: some View {
        let stages = ["Just curious", "Comparing options", "Saving up", "Almost ready to consult"]
        return VStack(spacing: 0) {
            progressBar(step: 2, total: 3)

            ScrollView(showsIndicators: false) {
                screenCard {
                    introBlock(eyebrow: "Step 2 of 3", title: "Where are you in your research?", body: "Tap to continue")

                    VStack(spacing: 10) {
                        ForEach(stages, id: \.self) { stage in
                            selectionPill(label: stage, isSelected: researchStage == stage) {
                                researchStage = stage
                                Analytics.onboardingStepCompleted(stepName: "research_stage", branch: .researching)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { push(.researchNeeds) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, stickyBottomPadding)
            }
        }
    }

    private var researchNeedsScreen: some View {
        let needs = ["Realistic results", "Recovery time", "Cost", "Finding a surgeon", "Complications", "Alternatives"]
        return VStack(spacing: 0) {
            progressBar(step: 3, total: 3)

            ScrollView(showsIndicators: false) {
                screenCard {
                    introBlock(eyebrow: "Step 3 of 3", title: "What would you most want answered?", body: "Select everything that matters to you.")

                    chipGrid(
                        options: needs,
                        selected: Array(researchNeeds),
                        multiSelect: true
                    ) { val in toggle(&researchNeeds, val) }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, stickyBottomPadding)
            }
        }
        .safeAreaInset(edge: .bottom) {
            blendedCTA {
                primaryButton(label: "Show me what's next", enabled: !researchNeeds.isEmpty) {
                    Analytics.onboardingStepCompleted(stepName: "research_needs", branch: .researching)
                    saveResearchData()
                    push(.personalizedTeaser)
                }
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Planning Path

    private var planProcedureScreen: some View {
        VStack(spacing: 0) {
            progressBar(step: 1, total: 4)

            ScrollView(showsIndicators: false) {
                screenCard {
                    introBlock(eyebrow: "Step 1 of 4", title: "Which procedure are you considering?", body: nil)

                    VStack(spacing: 10) {
                        ForEach(ProcedureOption.allCases) { option in
                            optionPill(
                                icon: option.icon,
                                title: option.rawValue,
                                desc: option.optionDescription,
                                isSelected: planProcedure == option
                            ) {
                                planProcedure = option
                                Analytics.onboardingStepCompleted(stepName: "plan_procedure", branch: .planning)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { push(.planConsultation) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private var planConsultationScreen: some View {
        let options = ["Not yet booked", "Booked", "Already had it"]
        return VStack(spacing: 0) {
            progressBar(step: 2, total: 4)

            ScrollView(showsIndicators: false) {
                screenCard {
                    introBlock(eyebrow: "Step 2 of 4", title: "Have you booked a consultation?", body: "Tap to continue")

                    VStack(spacing: 10) {
                        ForEach(options, id: \.self) { option in
                            selectionPill(label: option, isSelected: planConsultation == option) {
                                planConsultation = option
                                Analytics.onboardingStepCompleted(stepName: "plan_consultation", branch: .planning)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { push(.planHealth) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, stickyBottomPadding)
            }
        }
    }

    private var planHealthScreen: some View {
        VStack(spacing: 0) {
            progressBar(step: 3, total: 4)

            ScrollView(showsIndicators: false) {
                screenCard {
                    introBlock(eyebrow: "Step 3 of 4", title: "Any health considerations?", body: "This helps Rena flag anything relevant to your procedure.")

                    chipGrid(
                        options: ProfileSelectionCatalog.healthFlagOptions,
                        selected: Array(planHealthFlags),
                        multiSelect: true
                    ) { val in toggle(&planHealthFlags, val) }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, stickyBottomPadding)
            }
        }
        .safeAreaInset(edge: .bottom) {
            blendedCTA {
                VStack(spacing: 0) {
                    primaryButton(label: "Continue", enabled: true) {
                        Analytics.onboardingStepCompleted(stepName: "plan_health", branch: .planning)
                        push(.planTimeline)
                    }
                    skipButton {
                        Analytics.onboardingStepCompleted(stepName: "plan_health_skipped", branch: .planning)
                        push(.planTimeline)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var planTimelineScreen: some View {
        let options = ["Within a month", "1–3 months", "3–6 months", "Later", "Just open"]
        return VStack(spacing: 0) {
            progressBar(step: 4, total: 4)

            ScrollView(showsIndicators: false) {
                screenCard {
                    introBlock(eyebrow: "Step 4 of 4", title: "When are you hoping to do this?", body: "Tap to continue")

                    VStack(spacing: 10) {
                        ForEach(options, id: \.self) { option in
                            selectionPill(label: option, isSelected: planTimeline == option) {
                                planTimeline = option
                                Analytics.onboardingStepCompleted(stepName: "plan_timeline", branch: .planning)
                                savePlanningData()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { push(.personalizedTeaser) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, stickyBottomPadding)
            }
        }
    }

    // MARK: - Recovering Path

    private var recoverProcedureScreen: some View {
        VStack(spacing: 0) {
            progressBar(step: 1, total: 4)

            ScrollView(showsIndicators: false) {
                screenCard {
                    introBlock(eyebrow: "Step 1 of 4", title: "What did you have done?", body: nil)

                    VStack(spacing: 10) {
                        ForEach(ProcedureOption.allCases) { option in
                            optionPill(
                                icon: option.icon,
                                title: option.rawValue,
                                desc: option.optionDescription,
                                isSelected: recoverProcedures.contains(option)
                            ) {
                                if recoverProcedures.contains(option) {
                                    recoverProcedures.remove(option)
                                } else {
                                    recoverProcedures.insert(option)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, stickyBottomPadding)
            }
        }
        .safeAreaInset(edge: .bottom) {
            blendedCTA {
                primaryButton(label: "Continue", enabled: !recoverProcedures.isEmpty) {
                    Analytics.onboardingStepCompleted(stepName: "recover_procedure", branch: .recovering)
                    push(.recoverTiming)
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var recoverTimingScreen: some View {
        VStack(spacing: 0) {
            progressBar(step: 2, total: 4)

            ScrollView(showsIndicators: false) {
                screenCard {
                    introBlock(eyebrow: "Step 2 of 4", title: "When was your procedure?", body: "Tap to continue")

                    VStack(spacing: 10) {
                        ForEach(WhenOption.allCases) { option in
                            selectionPill(label: option.rawValue, isSelected: recoverWhen == option) {
                                recoverWhen = option
                                Analytics.onboardingStepCompleted(stepName: "recover_timing", branch: .recovering)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { push(.recoverHealth) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, stickyBottomPadding)
            }
        }
    }

    private var recoverHealthScreen: some View {
        VStack(spacing: 0) {
            progressBar(step: 3, total: 4)

            ScrollView(showsIndicators: false) {
                screenCard {
                    introBlock(eyebrow: "Step 3 of 4", title: "Any health considerations to factor in?", body: nil)

                    chipGrid(
                        options: ProfileSelectionCatalog.healthFlagOptions,
                        selected: Array(recoverHealthFlags),
                        multiSelect: true
                    ) { val in toggle(&recoverHealthFlags, val) }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, stickyBottomPadding)
            }
        }
        .safeAreaInset(edge: .bottom) {
            blendedCTA {
                VStack(spacing: 0) {
                    primaryButton(label: "Continue", enabled: true) {
                        Analytics.onboardingStepCompleted(stepName: "recover_health", branch: .recovering)
                        push(.recoverEmotion)
                    }
                    skipButton {
                        Analytics.onboardingStepCompleted(stepName: "recover_health_skipped", branch: .recovering)
                        push(.recoverEmotion)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var recoverEmotionScreen: some View {
        let options = ["Great", "Mostly good", "A bit anxious", "Worried about something specific"]
        return VStack(spacing: 0) {
            progressBar(step: 4, total: 4)

            ScrollView(showsIndicators: false) {
                screenCard {
                    introBlock(eyebrow: "Step 4 of 4", title: "How are you feeling about your recovery so far?", body: "Tap to continue")

                    VStack(spacing: 10) {
                        ForEach(options, id: \.self) { option in
                            selectionPill(label: option, isSelected: recoverEmotion == option) {
                                recoverEmotion = option
                                Analytics.onboardingStepCompleted(stepName: "recover_emotion", branch: .recovering)
                                saveRecoveringData()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { push(.personalizedTeaser) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, stickyBottomPadding)
            }
        }
    }

    // MARK: - Personalized Teaser Screen

    private var personalizedTeaserScreen: some View {
        VStack(spacing: 0) {
            Text("Rena")
                .font(.custom("Manrope", size: 14))
                .fontWeight(.medium)
                .italic()
                .tracking(4.5)
                .foregroundColor(OnboardingUI.roseDeep)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if teaserViewModel.isLoading {
                        teaserLoadingCard
                    } else if let content = teaserViewModel.content {
                        teaserContentCard(content)
                    } else if teaserViewModel.errorMessage != nil {
                        teaserErrorCard
                    } else {
                        teaserLoadingCard
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, stickyBottomPadding)
            }
        }
        .task {
            await loadTeaser()
            let branch = selectedBranch ?? .researching
            let procedure: String? = switch branch {
            case .researching: researchProcedures.sorted().first
            case .planning:    planProcedure?.storedName
            case .recovering:  recoverProcedures.first?.storedName
            }
            Analytics.personalizedTeaserViewed(branch: branch, procedure: procedure)
        }
        .safeAreaInset(edge: .bottom) {
            blendedCTA {
                primaryButton(
                    label: "See what's waiting for you",
                    enabled: teaserViewModel.content != nil || teaserViewModel.errorMessage != nil
                ) {
                    push(.softPitch)
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var teaserLoadingCard: some View {
        contentCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your free preview")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .tracking(2.2)

                Text("Building your personalized preview right now")
                    .font(.custom("Manrope", size: 26))
                    .fontWeight(.heavy)
                    .lineSpacing(2)
                    .padding(.top, 14)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Rena is analyzing your procedure details and goals")
                    Text("to generate insights specific to your situation")
                    Text("and what to expect in your recovery journey")
                }
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .lineSpacing(6)
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .frame(width: 22, height: 22)
                            Text("Personalized insight based on your recovery profile")
                                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 4)
            }
        }
        .redacted(reason: .placeholder)
    }

    private func teaserContentCard(_ content: OnboardingTeaserContent) -> some View {
        contentCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your free preview")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .tracking(2.2)
                    .textCase(.uppercase)
                    .foregroundColor(OnboardingUI.roseDeep)

                Text(content.headline)
                    .font(.custom("Manrope", size: 26))
                    .fontWeight(.heavy)
                    .foregroundColor(OnboardingUI.primaryInk)
                    .lineSpacing(2)
                    .padding(.top, 14)
                    .fixedSize(horizontal: false, vertical: true)

                Text(content.body)
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .foregroundColor(OnboardingUI.muted)
                    .lineSpacing(6)
                    .padding(.top, 16)
                    .fixedSize(horizontal: false, vertical: true)

                if !content.bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(content.bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 10) {
                                Text("→")
                                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                    .foregroundColor(OnboardingUI.roseDeep)
                                    .frame(width: 16, alignment: .leading)
                                Text(bullet)
                                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                    .foregroundColor(OnboardingUI.primaryInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 4)
                }

                Text("🔒 Subscribe to unlock your full plan")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                    .foregroundColor(OnboardingUI.rose)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
            }
        }
    }

    private var teaserErrorCard: some View {
        contentCard {
            VStack(spacing: 12) {
                Text("We couldn't generate your preview right now.")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                    .foregroundColor(OnboardingUI.primaryInk)
                    .multilineTextAlignment(.center)
                Text("Your personalized plan will be ready inside the app.")
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundColor(OnboardingUI.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Soft Pitch Screen

    private var softPitchScreen: some View {
        let bullets = softPitchBullets

        return ZStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: 0) {
                        // Rena logo mark hero
                        renaLogoMark(size: 72, color: OnboardingUI.primary)
                            .padding(.top, 60)
                            .padding(.bottom, 36)

                        Text("Enjoy a free week\nof Rena on us")
                            .font(.custom("Manrope", size: 32))
                            .fontWeight(.heavy)
                            .foregroundColor(OnboardingUI.primaryInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 24)

                        Text("Everything you need for your aesthetic journey,\npersonalized from day one.")
                            .font(.custom("PlusJakartaSans-Regular", size: 14))
                            .foregroundColor(OnboardingUI.muted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                            .padding(.top, 12)
                            .padding(.horizontal, 32)

                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(bullets, id: \.self) { bullet in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(OnboardingUI.primary)
                                        .frame(width: 22, height: 22)
                                        .background(OnboardingUI.primarySoft.opacity(0.7))
                                        .clipShape(Circle())
                                    Text(bullet)
                                        .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                                        .foregroundColor(OnboardingUI.primaryInk)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        .padding(.bottom, stickyBottomPadding)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                blendedCTA {
                    primaryButton(label: "Start free trial", enabled: true) {
                        push(.paywall)
                    }
                    .padding(.bottom, 8)
                }
            }

            // Confetti — plays once on appear, non-interactive
            LottieView(name: "Confetti-small", loop: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
        .onAppear { Analytics.softPitchViewed(branch: selectedBranch ?? .researching) }
    }

    private var softPitchBullets: [String] {
        switch selectedBranch {
        case .researching:
            return [
                "Deep-dives on every procedure you're considering",
                "Unlimited Ask Rena — answers in seconds, not days",
                "Consultation prep tailored to your goals",
                "Realistic results, timelines, and what surgeons don't always say",
                "Procedure comparisons side by side",
            ]
        case .planning:
            return [
                "Your full consultation prep, week by week",
                "Questions to ask based on your health history",
                "Unlimited Ask Rena — answers in seconds, not days",
                "Procedure deep-dives with realistic expectations",
                "Timeline tracking from first consult through recovery",
            ]
        case .recovering, .none:
            return [
                "Your full personalized roadmap, week by week",
                "Unlimited Ask Rena — answers in seconds, not days",
                "Photo timeline tracking with side-by-side comparison",
                "Consultation prep tailored to your goals and history",
                "Procedure deep-dives with realistic recovery expectations",
            ]
        }
    }

    // MARK: - Paywall Screen

    private var paywallScreen: some View {
        SubscriptionPaywallView(
            onDismiss: {
                Analytics.paywallDismissed(method: "skip")
                Task { await completeOnboardingWithoutSubscription() }
            },
            onMaybeLater: {
                withAnimation {
                    currentScreen = .discountOffer
                }
            },
            onSubscribed: {
                Task { @MainActor in completeOnboardingAfterSubscription() }
            }
        )
        .onAppear {
            Analytics.paywallViewed(branch: selectedBranch, source: "onboarding")
        }
    }

    // MARK: - Discount Offer Screen

    private var discountOfferScreen: some View {
        DiscountOfferView(
            onSubscribed: {
                Task { @MainActor in completeOnboardingAfterSubscription() }
            },
            onSkip: {
                Task { await completeOnboardingWithoutSubscription() }
            }
        )
    }

    // MARK: - Teaser loading

    private func loadTeaser() async {
        guard teaserViewModel.content == nil else { return }
        let request = buildTeaserRequest()
        await teaserViewModel.load(request: request)
    }

    private func buildTeaserRequest() -> OnboardingTeaserRequest {
        let isoFormatter = ISO8601DateFormatter()

        switch selectedBranch {
        case .researching, .none:
            return OnboardingTeaserRequest(
                branch: "researching",
                procedureName: researchProcedures.sorted().first,
                bodyAreas: Array(researchBodyAreas),
                healthFlags: [],
                researchStage: researchStage,
                researchNeeds: Array(researchNeeds),
                consultationStatus: nil,
                planningTimeline: nil,
                procedureDate: nil,
                emotionalState: nil
            )
        case .planning:
            return OnboardingTeaserRequest(
                branch: "planning",
                procedureName: planProcedure?.storedName,
                bodyAreas: nil,
                healthFlags: Array(planHealthFlags),
                researchStage: nil,
                researchNeeds: nil,
                consultationStatus: planConsultation,
                planningTimeline: planTimeline,
                procedureDate: nil,
                emotionalState: nil
            )
        case .recovering:
            let date = recoverWhen?.procedureDate
            return OnboardingTeaserRequest(
                branch: "recovering",
                procedureName: recoverProcedures.first?.storedName,
                bodyAreas: nil,
                healthFlags: Array(recoverHealthFlags),
                researchStage: nil,
                researchNeeds: nil,
                consultationStatus: nil,
                planningTimeline: nil,
                procedureDate: date.map { isoFormatter.string(from: $0) },
                emotionalState: recoverEmotion
            )
        }
    }

    // MARK: - Data save helpers

    private func saveResearchData() {
        OnboardingStore.saveUserContext(
            gender: nil, zipCode: nil, ageRange: nil, raceEthnicity: nil,
            aestheticGoals: [],
            proceduresOfInterest: Array(researchProcedures),
            previousProcedures: [],
            healthFlags: [],
            bodyAreas: Array(researchBodyAreas)
        )
        OnboardingStore.saveBranchData(
            branch: OnboardingBranch.researching.rawValue,
            researchStage: researchStage,
            researchNeeds: Array(researchNeeds)
        )
    }

    private func savePlanningData() {
        OnboardingStore.saveUserContext(
            gender: nil, zipCode: nil, ageRange: nil, raceEthnicity: nil,
            aestheticGoals: [],
            proceduresOfInterest: planProcedure.map { [$0.storedName] } ?? [],
            previousProcedures: [],
            healthFlags: Array(planHealthFlags),
            bodyAreas: []
        )
        OnboardingStore.saveBranchData(
            branch: OnboardingBranch.planning.rawValue,
            planningConsultation: planConsultation,
            planningTimeline: planTimeline
        )
    }

    private func saveRecoveringData() {
        if let when = recoverWhen, let proc = recoverProcedures.first {
            OnboardingStore.save(procedureName: proc.storedName, procedureDate: when.procedureDate)
        }
        OnboardingStore.saveUserContext(
            gender: nil, zipCode: nil, ageRange: nil, raceEthnicity: nil,
            aestheticGoals: [],
            proceduresOfInterest: [],
            previousProcedures: [],
            healthFlags: Array(recoverHealthFlags),
            bodyAreas: []
        )
        OnboardingStore.saveBranchData(
            branch: OnboardingBranch.recovering.rawValue,
            recoveringEmotion: recoverEmotion
        )
    }

    // MARK: - Onboarding completion

    @MainActor
    private func completeOnboardingWithoutSubscription() async {
        await completeOnboarding(reason: .maybeLater, source: "paywallMaybeLater")
    }

    @MainActor
    private func completeOnboardingAfterSubscription() {
        Task { await completeOnboarding(reason: .purchased, source: "paywallSubscribed") }
    }

    @MainActor
    private func completeOnboarding(reason: OnboardingCompletionReason, source: String) async {
        guard !isCompletingOnboarding else { return }
        isCompletingOnboarding = true
        OnboardingStore.completePostOnboardingFeedback()
        OnboardingStore.completeOnboarding(reason: reason, source: source)
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onFinish() }
        syncInBackground()
    }

    private func syncInBackground() {
        Task {
            await OnboardingStore.syncUserContextIfNeeded(using: userProfileService)
            await OnboardingStore.syncAttributionIfNeeded(using: userProfileService)
        }
    }

    @MainActor
    private func requestOnboardingReview() async {
        let outcome = await ReviewRequestHelper.requestWhenReady(
            initialDelayMilliseconds: 900,
            maxAttempts: 8,
            retryDelayMilliseconds: 500
        )
        if let message = outcome.userFacingMessage {
            activeAlert = .reviewUnavailable(message)
        }
    }

    // MARK: - Shared UI components

    // Flat passthrough — content sits directly on the background (Fluency style)
    private func screenCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
    }

    // Styled card — kept for AI teaser content where visual grouping helps
    private func contentCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(24)
            .background(OnboardingUI.surface)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(OnboardingUI.roseTint, lineWidth: 1)
            )
            .shadow(color: OnboardingUI.shadow.opacity(0.6), radius: 12, x: 0, y: 5)
    }

    private func introBlock(eyebrow: String, title: String, body: String?, titleSize: CGFloat = 34) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .font(Theme.PlusJakartaSans.semiBold(10))
                .foregroundColor(OnboardingUI.roseDeep)
                .tracking(2.3)
                .textCase(.uppercase)
            Text(title)
                .font(Theme.Manrope.extraBold(titleSize))
                .foregroundColor(OnboardingUI.primaryInk)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
            if let body, !body.isEmpty {
                Text(body)
                    .font(Theme.PlusJakartaSans.semiBold(13))
                    .foregroundColor(OnboardingUI.muted)
                    .lineSpacing(5)
                    .padding(.top, 16)
            }
        }
        .padding(.bottom, 24)
    }

    private func contextSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                .foregroundColor(OnboardingUI.primaryInk)
            content()
        }
    }

    private func chipGrid(options: [String], selected: [String], multiSelect: Bool, onTap: @escaping (String) -> Void) -> some View {
        ChipFlowLayout(itemSpacing: 8, rowSpacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = selected.contains(option)
                Button { onTap(option) } label: {
                    Text(option)
                        .font(.custom("PlusJakartaSans-Medium", size: 13))
                        .foregroundColor(isSelected ? OnboardingUI.roseDeep : OnboardingUI.primaryInk)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(isSelected ? OnboardingUI.roseSoft : OnboardingUI.surface)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                isSelected ? OnboardingUI.rose : OnboardingUI.roseTint,
                                lineWidth: 1.5
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectionPill(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.custom("PlusJakartaSans-Medium", size: 15))
                    .foregroundColor(isSelected ? OnboardingUI.roseDeep : OnboardingUI.primaryInk)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? OnboardingUI.primary : OnboardingUI.muted.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(isSelected ? OnboardingUI.roseSoft : OnboardingUI.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? OnboardingUI.rose : OnboardingUI.roseTint, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func optionPill(icon: String, title: String, desc: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(OnboardingUI.roseSoft.opacity(isSelected ? 0.92 : 0.55))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(OnboardingUI.roseDeep)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                        .foregroundColor(OnboardingUI.primaryInk)
                    Text(desc)
                        .font(.custom("PlusJakartaSans-Regular", size: 11))
                        .foregroundColor(OnboardingUI.muted)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(isSelected ? OnboardingUI.primary : Color.clear)
                        .frame(width: 18, height: 18)
                    Circle()
                        .stroke(isSelected ? OnboardingUI.primary : Color.black.opacity(0.08), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(isSelected ? OnboardingUI.roseSoft : OnboardingUI.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? OnboardingUI.rose : OnboardingUI.roseTint, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func progressBar(step: Int, total: Int) -> some View {
        HStack(spacing: 12) {
            Button { pop() } label: {
                ZStack {
                    Circle()
                        .fill(OnboardingUI.surface)
                        .frame(width: 38, height: 38)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(OnboardingUI.primaryInk)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(OnboardingUI.roseTint).frame(height: 3)
                    Capsule()
                        .fill(OnboardingUI.primary)
                        .frame(width: geo.size.width * CGFloat(step) / CGFloat(total), height: 3)
                        .animation(.easeInOut(duration: 0.3), value: step)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 16)
        .padding(.top, 58)
        .padding(.bottom, 24)
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        HStack {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 38, height: 38)
                        .shadow(color: OnboardingUI.shadow.opacity(0.34), radius: 5, x: 0, y: 2)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(OnboardingUI.roseDeep)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 58)
        .padding(.bottom, 16)
    }

    private func primaryButton(label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(enabled ? OnboardingUI.primary : OnboardingUI.primary.opacity(0.35))
                .clipShape(Capsule())
        }
        .disabled(!enabled)
        .padding(.horizontal, 24)
    }

    private func skipButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Skip for now")
                .font(.custom("PlusJakartaSans-Medium", size: 14))
                .foregroundColor(OnboardingUI.muted)
                .underline()
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 10)
    }

    private func blendedCTA<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.clear, OnboardingUI.bg.opacity(0.96)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 24)
            content()
                .background(OnboardingUI.bg.opacity(0.96))
        }
    }

    // MARK: - Helpers

    private func toggle(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

#Preview {
    OnboardingFlowView()
}
