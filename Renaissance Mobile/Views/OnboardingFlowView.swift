//
//  OnboardingFlowView.swift
//  Renaissance Mobile
//

import SwiftUI
import StripePaymentSheet

private enum OnboardingPaywallUI {
    static let shell = Color(hex: "#EEF1E8")
    static let bg = Color(hex: "#F6F7F2")
    static let surface = Color(hex: "#FBFCF8")
    static let card = Color(hex: "#EDF1E8")
    static let cardStrong = Color(hex: "#E1E7DA")
    static let text = Color(hex: "#1F261D")
    static let muted = Color(hex: "#687064")
    static let primary = Color(hex: "#516048")
    static let primaryInk = Color(hex: "#314030")
    static let primarySoft = Color(hex: "#D9E3CE")
    static let rose = Color(hex: "#B07B7A")
    static let roseSoft = Color(hex: "#F1DDDA")
    static let roseTint = Color(hex: "#EAD3D0")
    static let roseDeep = Color(hex: "#976769")
    static let shadow = Color(red: 90/255, green: 103/255, blue: 80/255).opacity(0.10)
}

private struct ChipFlowLayout: Layout {
    var itemSpacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? UIScreen.main.bounds.width - 72
        var currentX: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0, currentX + size.width > maxWidth {
                totalHeight += currentRowHeight + rowSpacing
                currentX = 0
                currentRowHeight = 0
            }

            currentRowHeight = max(currentRowHeight, size.height)
            currentX += size.width + (currentX > 0 ? itemSpacing : 0)
        }

        return CGSize(width: maxWidth, height: totalHeight + currentRowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > bounds.minX, currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += currentRowHeight + rowSpacing
                currentRowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            currentX += size.width + itemSpacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

// MARK: - Procedure Option

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

    var timelineNodes: [(time: String, desc: String, isCurrent: Bool)] {
        switch self {
        case .rhinoplasty:
            return [
                ("Today — Day 1–3", "Splint in place. Swelling and bruising around the nose and eyes is expected.", true),
                ("Days 7–10", "Splint removed. Significant swelling remains — resist judging the result.", false),
                ("Weeks 3–4", "Most bruising resolved. Initial shape begins to emerge.", false),
                ("Month 3–12", "Swelling continues to refine. Final result gradually reveals itself.", false),
            ]
        case .breastSurgery:
            return [
                ("Today — Day 1–3", "Tightness, soreness and swelling are normal. Rest and avoid all lifting.", true),
                ("Days 5–7", "Drains removed if placed. Discomfort begins to ease noticeably.", false),
                ("Weeks 3–6", "Implants or tissue begin settling into their final position.", false),
                ("Month 3–6", "Shape and softness finalise. Ideal time to assess your result.", false),
            ]
        case .bodyContouring:
            return [
                ("Today — Day 1–3", "Compression garment on. Swelling and bruising expected across treated areas.", true),
                ("Weeks 1–2", "Swelling peaks then slowly subsides. Garment must remain on.", false),
                ("Weeks 4–6", "Contours begin to emerge as swelling reduces.", false),
                ("Month 3–6", "Final shape becomes visible. Skin continues to retract and refine.", false),
            ]
        case .facialSurgery:
            return [
                ("Today — Day 1–3", "Swelling, bruising and tightness are significant. Rest fully, head elevated.", true),
                ("Days 7–10", "Sutures removed. Still bruised — avoid public-facing situations.", false),
                ("Weeks 3–4", "Most bruising fades. Presentable to most. Tightness lingers.", false),
                ("Month 2–3", "Swelling settles. Natural movement and expression return fully.", false),
            ]
        case .other:
            return [
                ("Today — Day 1–3", "Initial recovery phase. Rest and document any reactions daily.", true),
                ("Week 1–2", "Initial swelling reduces. Healing progresses steadily.", false),
                ("Week 2–4", "Results begin to settle and emerge.", false),
                ("Week 6+", "Assess outcomes and schedule any follow-up care.", false),
            ]
        }
    }
}

// MARK: - When Option

private enum WhenOption: String, CaseIterable, Identifiable {
    case oneToThreeDays  = "1–3 days ago"
    case fourToSevenDays = "4–7 days ago"
    case oneToTwoWeeks   = "1–2 weeks ago"
    case twoToSixWeeks   = "2–6 weeks ago"
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

// MARK: - OnboardingFlowView

struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    var onGetStarted: () -> Void = {}
    var onSignIn: () -> Void = {}

    @State private var screen = 0
    @State private var selectedProcedure: ProcedureOption? = nil
    @State private var selectedWhen: WhenOption? = nil
    @State private var selectedPlan = 0

    // Paywall / payment state
    @State private var email = ""
    @State private var paymentVM = OnboardingPaymentViewModel()
    @State private var isProcessingPayment = false
    @State private var paymentError: String? = nil

    // User context quiz state (screens 5–7)
    @State private var selectedGender: String? = nil
    @State private var selectedAgeRange: String? = nil
    @State private var selectedRaceEthnicity: String? = nil
    @State private var selectedAestheticGoals: Set<String> = []
    @State private var selectedBodyAreas: Set<String> = []
    @State private var selectedProceduresOfInterest: Set<String> = []
    @State private var selectedPreviousProcedures: Set<String> = []
    @State private var selectedHealthFlags: Set<String> = []

    private var isValidEmail: Bool {
        let regex = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }

    private var selectedPlanPriceId: String {
        switch selectedPlan {
        case 1:  return AppConfig.stripeMonthlyPriceId
        case 2:  return AppConfig.stripeWeeklyPriceId
        default: return AppConfig.stripeYearlyPriceId
        }
    }

    private let totalScreens = 7

    var body: some View {
        ZStack {
            onboardingShellBackground
                .ignoresSafeArea()
            Group {
                switch screen {
                case 0: hookScreen
                case 1: aboutYouScreen
                case 2: goalsScreen
                case 3: healthHistoryScreen
                case 4: whenScreen
                case 5: socialProofScreen
                default: paywallScreen
                }
            }
            .id(screen)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.3), value: screen)
        }
    }

    private var onboardingShellBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#F8FAF4"), Color(hex: "#EFF3E9")],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [OnboardingPaywallUI.rose.opacity(0.10), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 240
            )

            LinearGradient(
                colors: [OnboardingPaywallUI.roseSoft.opacity(0.26), Color.white.opacity(0)],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.24)
            )
        }
    }

    // MARK: - Screen 1: Hook

    private var hookScreen: some View {
        VStack(spacing: 0) {
            Text("Rena")
                .font(.custom("Manrope", size: 14))
                .fontWeight(.medium)
                .italic()
                .tracking(4.5)
                .foregroundColor(OnboardingPaywallUI.roseDeep)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 16)
                .padding(.bottom, 18)

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    onboardingScreenCard {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Step 1")
                                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                                .tracking(2.3)
                                .textCase(.uppercase)
                                .foregroundColor(OnboardingPaywallUI.roseDeep)
                                .padding(.top, 2)

                            Text("Your recovery, finally documented.")
                                .font(.custom("Manrope", size: 34))
                                .fontWeight(.heavy)
                                .tracking(-0.6)
                                .foregroundColor(OnboardingPaywallUI.primaryInk)
                                .lineSpacing(1)
                                .padding(.top, 18)

                            Text("Turn scattered memories, photo rolls, and half-remembered details into one calm record of what happened, when it happened, and how you healed.")
                                .font(.custom("PlusJakartaSans-Regular", size: 13))
                                .foregroundColor(OnboardingPaywallUI.muted)
                                .lineSpacing(6)
                                .padding(.top, 22)
                                .padding(.bottom, 22)

                            contrastGrid

                            Spacer(minLength: 24)

                            primaryButton(label: "Get Started", enabled: true, gradient: false, horizontalPadding: 0, topPadding: 0) {
                                withAnimation { screen = 1 }
                            }

                            HStack(spacing: 5) {
                                ForEach(0..<totalScreens, id: \.self) { i in
                                    Capsule()
                                        .fill(i == 0 ? OnboardingPaywallUI.roseDeep : OnboardingPaywallUI.roseSoft.opacity(0.75))
                                        .frame(width: i == 0 ? 24 : 6, height: 6)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)
                            .padding(.bottom, 2)
                        }
                        .frame(minHeight: proxy.size.height - 18, alignment: .top)
                    }
                    .frame(minHeight: proxy.size.height)
                    .padding(.top, 6)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(onboardingShellBackground.ignoresSafeArea())
    }

    private var contrastGrid: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Without tracking")
                    .font(.custom("PlusJakartaSans-Bold", size: 9))
                    .foregroundColor(OnboardingPaywallUI.muted)
                    .tracking(2.2)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 2)

                contrastDot(text: "Forgot when you last had Botox", good: false)
                contrastDot(text: "Can't remember your units or provider", good: false)
                contrastDot(text: "No photos to compare results", good: false)
                contrastDot(text: "Noticed something off — waited too long", good: false)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(OnboardingPaywallUI.card)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black.opacity(0.05), lineWidth: 1))

            VStack(alignment: .leading, spacing: 12) {
                Text("With Rena")
                    .font(.custom("PlusJakartaSans-Bold", size: 9))
                    .foregroundColor(OnboardingPaywallUI.roseDeep)
                    .tracking(2.2)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 2)

                contrastDot(text: "Knows exactly what was done & when", good: true)
                contrastDot(text: "Day 1 through week 4 — all documented", good: true)
                contrastDot(text: "Chose the right provider next time", good: true)
                contrastDot(text: "Caught early bruising before it worsened", good: true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#F6E5E8"), Color(hex: "#EED6DC")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(OnboardingPaywallUI.roseSoft.opacity(0.7), lineWidth: 1))
        }
    }

    private func contrastDot(text: String, good: Bool) -> some View {
        Text(text)
            .font(.custom("PlusJakartaSans-Regular", size: 12))
            .foregroundColor(good ? OnboardingPaywallUI.primaryInk : OnboardingPaywallUI.muted)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(5)
    }

    // MARK: - Screen 2: Q1 Procedure

    // MARK: - Screen 4: When

    private var whenScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            questionTopBar(step: 4, total: 4)

            ScrollView(showsIndicators: false) {
                onboardingScreenCard {
                    introBlock(
                        eyebrow: "Your timing",
                        title: "When did it happen?",
                        body: "This helps us find where you are in your recovery right now."
                    )

                    VStack(spacing: 12) {
                        ForEach(WhenOption.allCases) { option in
                            whenPill(option)
                        }
                    }
                    .padding(.top, 4)

                    primaryButton(label: "Continue", enabled: selectedWhen != nil, gradient: false, horizontalPadding: 0, topPadding: 28) {
                        if let when = selectedWhen {
                            OnboardingStore.save(procedureName: selectedProcedure?.storedName ?? "Surgery", procedureDate: when.procedureDate)
                        }
                        withAnimation { screen = 5 }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
            Spacer().frame(height: 14)
        }
    }

    // MARK: - Screen 5: Social Proof

    private var socialProofScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 14)

            ScrollView(showsIndicators: false) {
                onboardingScreenCard {
                    introBlock(
                        eyebrow: "The difference it makes",
                        title: "Trackers vs. non-trackers.",
                        body: "Real outcomes from patients who documented their recovery from day one.",
                        eyebrowColor: OnboardingPaywallUI.roseDeep
                    )

                    VStack(spacing: 12) {
                        statCard(number: "30%",
                                 title: "Higher satisfaction with their result",
                                 desc: "Patients using photo-based recovery tracking report better outcomes and arrive to follow-ups fully prepared")
                        statCard(number: "2 in 5",
                                 title: "Go on to have another procedure",
                                 desc: "Your documented recovery becomes a personal health record — sharper decisions every time")
                        statCard(number: "1 in 4",
                                 title: "Surgical records have missing fields",
                                 desc: "Patients who self-document always have the full picture — dates, photos, and how they healed")
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 14)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("\"My surgeon told me it takes a full year to see the final result. I had no idea what 'normal' looked like week by week — logging photos gave me something to actually reference at every check-up.\"")
                            .font(.custom("PlusJakartaSans-Regular", size: 12))
                            .foregroundColor(OnboardingPaywallUI.primaryInk)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Maya R. · Beta user")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                            .foregroundColor(OnboardingPaywallUI.roseDeep)
                        Text("Rhinoplasty · 4 months post-op")
                            .font(.custom("PlusJakartaSans-Regular", size: 10))
                            .foregroundColor(OnboardingPaywallUI.muted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OnboardingPaywallUI.roseSoft.opacity(0.94))
                    .cornerRadius(24)

                    primaryButton(label: "I'm ready", enabled: true, gradient: false, horizontalPadding: 0, topPadding: 28) {
                        withAnimation { screen = 6 }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
            Spacer().frame(height: 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statCard(number: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.custom("Manrope", size: 34))
                .fontWeight(.bold)
                .foregroundColor(OnboardingPaywallUI.roseDeep)
                .frame(width: 88, alignment: .center)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                    .foregroundColor(OnboardingPaywallUI.primaryInk)
                    .lineSpacing(2)
                Text(desc)
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundColor(OnboardingPaywallUI.muted)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OnboardingPaywallUI.card)
        .cornerRadius(22)
    }

    // MARK: - Screen 6: Paywall

    private var paywallScreen: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                onboardingScreenCard {
                    ZStack {
                        Text("Unlock the full experience")
                            .font(.custom("Manrope", size: 25))
                            .fontWeight(.black)
                            .foregroundColor(OnboardingPaywallUI.primaryInk)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Button {
                            OnboardingStore.hasCompleted = true
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onSignIn() }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(OnboardingPaywallUI.primaryInk)
                                .frame(width: 32, height: 32)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                )
                                .opacity(0.82)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                    .padding(.bottom, 14)

                    VStack(spacing: 10) {
                        onboardingFeaturedAnnualCard
                        onboardingCompactPlanCard(
                            name: "Gold",
                            price: paymentVM.monthlyPriceInfo?.displayPrice ?? "—",
                            tierIndex: 1
                        )
                        onboardingCompactPlanCard(
                            name: "Silver",
                            price: paymentVM.weeklyPriceInfo?.displayPrice ?? "—",
                            tierIndex: 2
                        )
                    }
                    .padding(.bottom, 12)
                    .task { await paymentVM.fetchPrices() }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("What your plan unlocks")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                            .tracking(2.3)
                            .foregroundColor(OnboardingPaywallUI.muted)
                            .textCase(.uppercase)

                        VStack(spacing: 10) {
                            unlockCard(
                                icon: "ellipsis.message",
                                tint: OnboardingPaywallUI.primarySoft,
                                iconColor: OnboardingPaywallUI.primary,
                                title: "Continue Ask Rena without interruptions"
                            )
                            unlockCard(
                                icon: "chart.line.text.clipboard",
                                tint: OnboardingPaywallUI.roseSoft,
                                iconColor: OnboardingPaywallUI.roseDeep,
                                title: "Turn your history into better guidance"
                            )
                            unlockCard(
                                icon: "bookmark",
                                tint: OnboardingPaywallUI.roseSoft.opacity(0.9),
                                iconColor: OnboardingPaywallUI.roseDeep,
                                title: "Get more value from every saved procedure"
                            )
                        }
                    }
                    .padding(16)
                    .background(OnboardingPaywallUI.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(OnboardingPaywallUI.roseSoft.opacity(0.8), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .padding(.bottom, 12)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Email for secure checkout")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                            .foregroundColor(OnboardingPaywallUI.roseDeep)
                            .tracking(1.8)
                            .textCase(.uppercase)

                        Text("We’ll use this to create your account and connect your plan after checkout.")
                            .font(.custom("PlusJakartaSans-Regular", size: 12))
                            .foregroundColor(OnboardingPaywallUI.muted)
                            .lineSpacing(4)

                        TextField("your@email.com", text: $email)
                            .font(.custom("PlusJakartaSans-Regular", size: 14))
                            .foregroundColor(OnboardingPaywallUI.primaryInk)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(OnboardingPaywallUI.card)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        isValidEmail ? OnboardingPaywallUI.rose.opacity(0.35) : OnboardingPaywallUI.roseSoft.opacity(0.7),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
                    .padding(.bottom, 14)

                    // Payment error
                    if let error = paymentError {
                        Text(error)
                            .font(.custom("PlusJakartaSans-Regular", size: 11))
                            .foregroundColor(Color(hex: "#C0392B"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }

                    Button {
                        Task {
                            isProcessingPayment = true
                            paymentError = nil
                            let prepared = await paymentVM.prepareSubscriptionPaymentSheet(
                                email: email,
                                priceId: selectedPlanPriceId
                            )
                            guard prepared else {
                                paymentError = paymentVM.errorMessage ?? "Something went wrong. Please try again."
                                isProcessingPayment = false
                                return
                            }
                            let result = await paymentVM.presentPaymentSheet()
                            switch result {
                            case .completed:
                                if let cId = paymentVM.lastCustomerId,
                                   let sId = paymentVM.lastSubscriptionId {
                                    OnboardingStore.saveStripeData(email: email, customerId: cId, subscriptionId: sId)
                                }
                                OnboardingStore.hasCompleted = true
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onGetStarted() }
                            case .failed(let error):
                                paymentError = error.localizedDescription
                            case .canceled:
                                break
                            }
                            isProcessingPayment = false
                        }
                    } label: {
                        Group {
                            if isProcessingPayment {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Continue to secure checkout")
                                    .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                                    .foregroundColor(.white)
                                    .tracking(0.3)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Group {
                                if isValidEmail && !isProcessingPayment {
                                    OnboardingPaywallUI.primary
                                } else {
                                    OnboardingPaywallUI.primary.opacity(0.35)
                                }
                            }
                        )
                        .cornerRadius(24)
                        .shadow(
                            color: isValidEmail ? OnboardingPaywallUI.shadow : Color.clear,
                            radius: 8, x: 0, y: 5
                        )
                    }
                    .disabled(!isValidEmail || isProcessingPayment)
                    .padding(.bottom, 10)

                    if !isProcessingPayment {
                        VStack(spacing: 5) {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(OnboardingPaywallUI.roseDeep)
                                Text("100% money back")
                                    .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                                    .foregroundColor(OnboardingPaywallUI.roseDeep)
                            }
                            Text("Cancel anytime. No pressure.")
                                .font(.custom("PlusJakartaSans-Regular", size: 11))
                                .foregroundColor(OnboardingPaywallUI.muted)
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        )
                        .padding(.bottom, 12)
                    }

                    Button {
                        OnboardingStore.hasCompleted = true
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onSignIn() }
                    } label: {
                        Text("Already have an account? Sign In")
                            .font(.custom("PlusJakartaSans-Regular", size: 13))
                            .foregroundColor(OnboardingPaywallUI.muted)
                            .underline()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                }
                .padding(.top, 18)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(OnboardingPaywallUI.bg.ignoresSafeArea())
    }

    // MARK: - Screen 6: About You

    private var aboutYouScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            questionTopBar(step: 1, total: 4)

            ScrollView(showsIndicators: false) {
                onboardingScreenCard {
                    introBlock(
                        eyebrow: "About you",
                        title: "Help Rena know you better.",
                        body: "This helps us tailor guidance to your healing, skin, and aesthetic journey. All optional."
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        contextSection(title: "Gender identity") {
                            chipGrid(options: ProfileSelectionCatalog.genderOptions,
                                     selected: selectedGender.map { [$0] } ?? [],
                                     multiSelect: false) { val in
                                selectedGender = selectedGender == val ? nil : val
                            }
                        }
                        contextSection(title: "Age range") {
                            chipGrid(options: ProfileSelectionCatalog.ageRangeOptions,
                                     selected: selectedAgeRange.map { [$0] } ?? [],
                                     multiSelect: false) { val in
                                selectedAgeRange = selectedAgeRange == val ? nil : val
                            }
                        }
                        contextSection(title: "Race / Ethnicity") {
                            chipGrid(
                                options: ProfileSelectionCatalog.raceOptions,
                                selected: selectedRaceEthnicity.map { [$0] } ?? [],
                                multiSelect: false
                            ) { val in
                                selectedRaceEthnicity = selectedRaceEthnicity == val ? nil : val
                            }
                        }
                    }

                    primaryButton(label: "Continue", enabled: true, gradient: false, horizontalPadding: 0, topPadding: 28) {
                        withAnimation { screen = 2 }
                    }

                    secondarySkipButton {
                        withAnimation { screen = 2 }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            Spacer().frame(height: 14)
        }
    }

    // MARK: - Screen 7: Goals & Interests

    private var goalsScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            questionTopBar(step: 2, total: 4)

            ScrollView(showsIndicators: false) {
                onboardingScreenCard {
                    introBlock(
                        eyebrow: "Your goals",
                        title: "What are you hoping to achieve?",
                        body: "Select all that apply. This shapes the advice and insights Rena gives you."
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        contextSection(title: "Aesthetic goals") {
                            chipGrid(
                                options: ProfileSelectionCatalog.goalOptions,
                                selected: Array(selectedAestheticGoals),
                                multiSelect: true
                            ) { val in
                                if selectedAestheticGoals.contains(val) { selectedAestheticGoals.remove(val) }
                                else { selectedAestheticGoals.insert(val) }
                            }
                        }
                        contextSection(title: "Body areas of interest") {
                            chipGrid(
                                options: ProfileSelectionCatalog.bodyAreaOptions,
                                selected: Array(selectedBodyAreas),
                                multiSelect: true
                            ) { val in
                                if selectedBodyAreas.contains(val) { selectedBodyAreas.remove(val) }
                                else { selectedBodyAreas.insert(val) }
                            }
                        }
                        contextSection(title: "Procedures you're considering") {
                            chipGrid(
                                options: ProfileSelectionCatalog.procedureOptions,
                                selected: Array(selectedProceduresOfInterest),
                                multiSelect: true
                            ) { val in
                                if selectedProceduresOfInterest.contains(val) { selectedProceduresOfInterest.remove(val) }
                                else { selectedProceduresOfInterest.insert(val) }
                            }
                        }
                    }

                    primaryButton(label: "Continue", enabled: true, gradient: false, horizontalPadding: 0, topPadding: 28) {
                        withAnimation { screen = 3 }
                    }

                    secondarySkipButton {
                        withAnimation { screen = 3 }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            Spacer().frame(height: 14)
        }
    }

    // MARK: - Screen 8: Health & History

    private var healthHistoryScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            questionTopBar(step: 3, total: 4)

            ScrollView(showsIndicators: false) {
                onboardingScreenCard {
                    introBlock(
                        eyebrow: "Health & history",
                        title: "A few quick context questions.",
                        body: "Not a diagnosis — just helps Rena personalise your recovery guidance."
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        contextSection(title: "Procedures you've already had") {
                            chipGrid(
                                options: ProfileSelectionCatalog.previousProcedureOptions,
                                selected: Array(selectedPreviousProcedures),
                                multiSelect: true
                            ) { val in
                                if selectedPreviousProcedures.contains(val) { selectedPreviousProcedures.remove(val) }
                                else { selectedPreviousProcedures.insert(val) }
                            }
                        }
                        contextSection(title: "Any health considerations?") {
                            chipGrid(
                                options: ProfileSelectionCatalog.healthFlagOptions,
                                selected: Array(selectedHealthFlags),
                                multiSelect: true
                            ) { val in
                                if selectedHealthFlags.contains(val) { selectedHealthFlags.remove(val) }
                                else { selectedHealthFlags.insert(val) }
                            }
                        }
                    }

                    primaryButton(label: "Continue", enabled: true, gradient: false, horizontalPadding: 0, topPadding: 28) {
                        OnboardingStore.saveUserContext(
                            gender: selectedGender,
                            zipCode: nil,
                            ageRange: selectedAgeRange,
                            raceEthnicity: selectedRaceEthnicity,
                            aestheticGoals: Array(selectedAestheticGoals),
                            proceduresOfInterest: Array(selectedProceduresOfInterest),
                            previousProcedures: Array(selectedPreviousProcedures),
                            healthFlags: Array(selectedHealthFlags),
                            bodyAreas: Array(selectedBodyAreas)
                        )
                        withAnimation { screen = 4 }
                    }

                    secondarySkipButton {
                        OnboardingStore.saveUserContext(
                            gender: selectedGender,
                            zipCode: nil,
                            ageRange: selectedAgeRange,
                            raceEthnicity: selectedRaceEthnicity,
                            aestheticGoals: Array(selectedAestheticGoals),
                            proceduresOfInterest: Array(selectedProceduresOfInterest),
                            previousProcedures: Array(selectedPreviousProcedures),
                            healthFlags: Array(selectedHealthFlags),
                            bodyAreas: Array(selectedBodyAreas)
                        )
                        withAnimation { screen = 4 }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
            Spacer().frame(height: 14)
        }
    }

    // MARK: - Context Quiz Helpers

    private func contextSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                .foregroundColor(OnboardingPaywallUI.primaryInk)
                .tracking(0.2)
            content()
        }
    }

    private func onboardingScreenCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: OnboardingPaywallUI.shadow.opacity(0.8), radius: 14, x: 0, y: 6)
    }

    private func chipGrid(options: [String], selected: [String], multiSelect: Bool, onTap: @escaping (String) -> Void) -> some View {
        ChipFlowLayout(itemSpacing: 8, rowSpacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = selected.contains(option)
                Button { onTap(option) } label: {
                    Text(option)
                        .font(.custom("PlusJakartaSans-Medium", size: 13))
                        .foregroundColor(isSelected ? Color(hex: "#5F4546") : OnboardingPaywallUI.primaryInk)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background {
                            if isSelected {
                                LinearGradient(
                                    colors: [Color(hex: "#F5E3E0"), Color(hex: "#F8EFED")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            } else {
                                Color.white.opacity(0.88)
                            }
                        }
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? OnboardingPaywallUI.rose.opacity(0.46) : Color.black.opacity(0.05), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Shared Components

    private func introBlock(
        eyebrow: String,
        title: String,
        body: String,
        eyebrowColor: Color = OnboardingPaywallUI.muted,
        titleSize: CGFloat = 36
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                .foregroundColor(eyebrowColor)
                .tracking(2.3)
                .textCase(.uppercase)

            Text(title)
                .font(.custom("Manrope", size: titleSize))
                .fontWeight(.black)
                .foregroundColor(OnboardingPaywallUI.primaryInk)
                .lineSpacing(2)
                .padding(.top, 16)

            Text(body)
                .font(.custom("PlusJakartaSans-Regular", size: 13))
                .foregroundColor(OnboardingPaywallUI.muted)
                .lineSpacing(6)
                .padding(.top, 20)
                .padding(.bottom, 28)
        }
    }

    private func questionTopBar(step: Int, total: Int) -> some View {
        HStack(spacing: 10) {
            Button { withAnimation { screen -= 1 } } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 38, height: 38)
                        .shadow(color: OnboardingPaywallUI.shadow.opacity(0.34), radius: 5, x: 0, y: 2)
                    Circle()
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                        .frame(width: 38, height: 38)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(OnboardingPaywallUI.roseDeep)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(OnboardingPaywallUI.rose.opacity(0.16)).frame(height: 4)
                    Capsule()
                        .fill(OnboardingPaywallUI.roseDeep)
                        .frame(width: geo.size.width * CGFloat(step) / CGFloat(total), height: 4)
                }
            }
            .frame(height: 4)

            Text("\(step) of \(total)")
                .font(.custom("PlusJakartaSans-Medium", size: 11))
                .foregroundColor(OnboardingPaywallUI.muted)
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.top, 58)
        .padding(.bottom, 24)
    }

    private func optionPill(icon: String, title: String, desc: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                // Rounded-rect icon (not circle)
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(OnboardingPaywallUI.roseSoft.opacity(isSelected ? 0.92 : 0.55))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(OnboardingPaywallUI.roseDeep)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                        .foregroundColor(OnboardingPaywallUI.primaryInk)
                    Text(desc)
                        .font(.custom("PlusJakartaSans-Regular", size: 11))
                        .foregroundColor(OnboardingPaywallUI.muted)
                }

                Spacer()

                // Circle check
                ZStack {
                    Circle()
                        .fill(isSelected ? OnboardingPaywallUI.primary : Color.clear)
                        .frame(width: 18, height: 18)
                    Circle()
                        .stroke(isSelected ? OnboardingPaywallUI.primary : Color.black.opacity(0.08), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(isSelected ? OnboardingPaywallUI.roseSoft.opacity(0.9) : Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? OnboardingPaywallUI.rose.opacity(0.45) : Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: OnboardingPaywallUI.shadow.opacity(0.5), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func whenPill(_ option: WhenOption) -> some View {
        let isSelected = selectedWhen == option
        return Button {
            withAnimation(.spring(response: 0.3)) { selectedWhen = option }
        } label: {
            HStack {
                Text(option.rawValue)
                    .font(.custom("PlusJakartaSans-Medium", size: 14))
                    .foregroundColor(isSelected ? Color(hex: "#5F4546") : OnboardingPaywallUI.primaryInk)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
            .background {
                if isSelected {
                    LinearGradient(
                        colors: [Color(hex: "#F5E3E0"), Color(hex: "#F8EFED")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    Color.white.opacity(0.88)
                }
            }
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? OnboardingPaywallUI.rose.opacity(0.46) : Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var onboardingAnnualSupportText: String {
        let annualPrice = paymentVM.yearlyPriceInfo?.displayPrice ?? "—"
        return annualPrice == "—" ? "Billed yearly" : "About $17.99/mo billed yearly"
    }

    private func onboardingPlanDescription(for tierIndex: Int) -> String {
        switch tierIndex {
        case 0: return "Everything in Gold with the strongest long-term value."
        case 1: return "For consistent support across chat, research, and journal."
        default: return "A lighter starting point for occasional AI help."
        }
    }

    private func onboardingPlanPerks(for tierIndex: Int) -> [String] {
        switch tierIndex {
        case 0, 1: return ["75 msgs", "15 imgs", "210 credits"]
        default: return ["30 msgs", "5 imgs", "80 credits"]
        }
    }

    private func onboardingPlanUnit(for tierIndex: Int) -> String {
        switch tierIndex {
        case 0: return "/yr"
        case 2: return "/wk"
        default: return "/mo"
        }
    }

    private func normalizedPriceText(_ rawPrice: String) -> String {
        rawPrice
            .replacingOccurrences(of: "/yr", with: "")
            .replacingOccurrences(of: "/mo", with: "")
            .replacingOccurrences(of: "/wk", with: "")
            .replacingOccurrences(of: "/week", with: "")
            .replacingOccurrences(of: "/month", with: "")
            .replacingOccurrences(of: "/year", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func onboardingPriceDisplay(_ rawPrice: String, tierIndex: Int) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(rawPrice == "—" ? "—" : normalizedPriceText(rawPrice))
                .font(.custom("Manrope", size: 18))
                .fontWeight(.bold)
                .foregroundColor(OnboardingPaywallUI.primaryInk)
            Text(onboardingPlanUnit(for: tierIndex))
                .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                .foregroundColor(OnboardingPaywallUI.muted)
                .padding(.leading, 4)
        }
    }

    private func onboardingSelectionDot(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? OnboardingPaywallUI.primary : Color.black.opacity(0.10), lineWidth: 2)
                .frame(width: 18, height: 18)
            if isSelected {
                Circle()
                    .fill(OnboardingPaywallUI.primary)
                    .frame(width: 18, height: 18)
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var onboardingFeaturedAnnualCard: some View {
        let annualPrice = paymentVM.yearlyPriceInfo?.displayPrice ?? "—"
        let isSelected = selectedPlan == 0
        return Button { selectedPlan = 0 } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Annual")
                                .font(.custom("Manrope", size: 17))
                                .fontWeight(.bold)
                                .foregroundColor(OnboardingPaywallUI.primaryInk)
                            Text("Best Value")
                                .font(.custom("PlusJakartaSans-Bold", size: 9))
                                .foregroundColor(.white)
                                .tracking(1.3)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(OnboardingPaywallUI.rose)
                                .clipShape(Capsule())
                        }
                        Text(onboardingPlanDescription(for: 0))
                            .font(.custom("PlusJakartaSans-Regular", size: 12))
                            .foregroundColor(OnboardingPaywallUI.muted)
                            .lineSpacing(3)
                    }

                    Spacer()
                    onboardingSelectionDot(isSelected: isSelected)
                        .padding(.top, 2)
                }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        onboardingPriceDisplay(annualPrice, tierIndex: 0)
                        Text(onboardingAnnualSupportText)
                            .font(.custom("PlusJakartaSans-Regular", size: 11))
                            .foregroundColor(OnboardingPaywallUI.roseDeep)
                    }

                    Spacer(minLength: 10)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Includes")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 8))
                            .tracking(1.6)
                            .foregroundColor(OnboardingPaywallUI.muted)
                            .textCase(.uppercase)
                        Text(onboardingPlanPerks(for: 0).joined(separator: " • "))
                            .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                            .foregroundColor(OnboardingPaywallUI.primaryInk)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background(OnboardingPaywallUI.roseSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(15)
            .background(isSelected ? OnboardingPaywallUI.surface : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(isSelected ? OnboardingPaywallUI.rose.opacity(0.42) : Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: isSelected ? OnboardingPaywallUI.shadow.opacity(0.55) : Color.clear, radius: 7, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func onboardingCompactPlanCard(name: String, price: String, tierIndex: Int) -> some View {
        let isSelected = selectedPlan == tierIndex
        return Button { selectedPlan = tierIndex } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.custom("Manrope", size: 17))
                            .fontWeight(.bold)
                            .foregroundColor(OnboardingPaywallUI.primaryInk)
                        Text(onboardingPlanDescription(for: tierIndex))
                            .font(.custom("PlusJakartaSans-Regular", size: 11))
                            .foregroundColor(OnboardingPaywallUI.muted)
                            .lineSpacing(3)
                    }
                    Spacer()
                    onboardingSelectionDot(isSelected: isSelected)
                        .padding(.top, 2)
                }

                HStack(alignment: .lastTextBaseline) {
                    onboardingPriceDisplay(price, tierIndex: tierIndex)
                    Spacer()
                    Text(onboardingPlanPerks(for: tierIndex).joined(separator: " • "))
                        .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                        .foregroundColor(OnboardingPaywallUI.muted)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(isSelected ? OnboardingPaywallUI.surface : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(isSelected ? OnboardingPaywallUI.primary.opacity(0.34) : OnboardingPaywallUI.roseSoft.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: isSelected ? OnboardingPaywallUI.shadow.opacity(0.45) : Color.clear, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func unlockCard(icon: String, tint: some ShapeStyle, iconColor: Color, title: String, body: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                    .foregroundColor(OnboardingPaywallUI.primaryInk)
                if let body {
                    Text(body)
                        .font(.custom("PlusJakartaSans-Regular", size: 12))
                        .foregroundColor(OnboardingPaywallUI.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(OnboardingPaywallUI.roseSoft.opacity(0.65), lineWidth: 1)
        )
    }

    private func primaryButton(
        label: String,
        enabled: Bool,
        gradient: Bool,
        horizontalPadding: CGFloat = 16,
        topPadding: CGFloat = 14,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background {
                    if !enabled {
                        OnboardingPaywallUI.primary.opacity(0.35).cornerRadius(24)
                    } else {
                        OnboardingPaywallUI.primary.cornerRadius(24)
                    }
                }
                .shadow(color: enabled ? OnboardingPaywallUI.shadow.opacity(0.8) : Color.clear, radius: 10, x: 0, y: 5)
        }
        .disabled(!enabled)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
    }

    private func secondarySkipButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Skip for now")
                .font(.custom("PlusJakartaSans-Medium", size: 14))
                .foregroundColor(OnboardingPaywallUI.muted)
                .underline()
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 14)
    }
}

#Preview {
    OnboardingFlowView()
}
