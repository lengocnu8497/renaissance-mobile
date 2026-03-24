//
//  OnboardingFlowView.swift
//  Renaissance Mobile
//

import SwiftUI
import StripePaymentSheet

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

    private var isValidEmail: Bool {
        let regex = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }

    private var selectedPlanPriceId: String {
        switch selectedPlan {
        case 1:  return EnvironmentConfig.stripeGoldPriceId
        case 2:  return EnvironmentConfig.stripeSilverPriceId
        default: return EnvironmentConfig.stripeAnnualPriceId
        }
    }

    private let totalScreens = 6

    var body: some View {
        ZStack {
            Color(hex: "#FFF8F6").ignoresSafeArea()
            Group {
                switch screen {
                case 0: hookScreen
                case 1: procedureScreen
                case 2: whenScreen
                case 3: projectionScreen
                case 4: socialProofScreen
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

    // MARK: - Screen 1: Hook

    private var hookScreen: some View {
        VStack(spacing: 0) {
            // Logo — pinned top
            Text("Rena")
                .font(.system(size: 13, weight: .medium, design: .serif))
                .italic()
                .tracking(5)
                .foregroundColor(Color(hex: "#8E4C5C"))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 14)
                .padding(.bottom, 10)

            // Headline — pinned top
            (
                Text("Your recovery,\n")
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .foregroundColor(Color(hex: "#3D2B2E"))
                +
                Text("finally documented.")
                    .font(.system(size: 23, weight: .light, design: .serif))
                    .italic()
                    .foregroundColor(Color(hex: "#8E4C5C"))
            )
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            // Contrast grid — flex: 1 (fills all remaining space)
            contrastGrid
                .padding(.bottom, 14)

            // CTA — pinned bottom
            Button { withAnimation { screen = 1 } } label: {
                Text("Get Started")
                    .font(.custom("Outfit-SemiBold", size: 13.5))
                    .foregroundColor(.white)
                    .tracking(0.4)
                    .frame(maxWidth: .infinity)
                    .frame(height: 43)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#6B3346"), Color(hex: "#8E4C5C"), Color(hex: "#B76E79")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color(hex: "#6B3346").opacity(0.34), radius: 8, x: 0, y: 5)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            // Progress dots — pinned bottom
            HStack(spacing: 5) {
                ForEach(0..<totalScreens, id: \.self) { i in
                    Capsule()
                        .fill(i == 0 ? Color(hex: "#8E4C5C") : Color(hex: "#C4929A").opacity(0.14))
                        .frame(width: i == 0 ? 18 : 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 18)
        }
    }

    private var contrastGrid: some View {
        HStack(alignment: .top, spacing: 7) {
            // Without tracking — fills available height
            VStack(alignment: .leading, spacing: 8) {
                Text("Without tracking")
                    .font(.custom("Outfit-Bold", size: 7.5))
                    .foregroundColor(Color(hex: "#B8A9AB"))
                    .tracking(2)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 7)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color(hex: "#B8A9AB").opacity(0.35)).frame(height: 1)
                    }

                contrastDot(text: "Forgot when you last had Botox", good: false)
                contrastDot(text: "Can't remember your units or provider", good: false)
                contrastDot(text: "No photos to compare results", good: false)
                contrastDot(text: "Noticed something off — waited too long", good: false)
            }
            .padding(11)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(hex: "#F5F0F1"))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#B8A9AB").opacity(0.25), lineWidth: 1))

            // With Rena — fills available height
            VStack(alignment: .leading, spacing: 8) {
                Text("With Rena")
                    .font(.custom("Outfit-Bold", size: 7.5))
                    .foregroundColor(Color(hex: "#8E4C5C"))
                    .tracking(2)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 7)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color(hex: "#8E4C5C").opacity(0.25)).frame(height: 1)
                    }

                contrastDot(text: "Knows exactly what was done & when", good: true)
                contrastDot(text: "Day 1 through week 4 — all documented", good: true)
                contrastDot(text: "Chose the right provider next time", good: true)
                contrastDot(text: "Caught early bruising before it worsened", good: true)
            }
            .padding(11)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#f8e9ef"), Color(hex: "#f0d2da")],
                    startPoint: UnitPoint(x: 0.14, y: 0),
                    endPoint: UnitPoint(x: 0.86, y: 1)
                )
            )
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#C4929A").opacity(0.28), lineWidth: 1))
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 18)
    }

    private func contrastDot(text: String, good: Bool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(good ? Color(hex: "#8E4C5C") : Color(hex: "#B8A9AB"))
                .frame(width: 4, height: 4)
                .padding(.top, 4)
            Text(text)
                .font(.custom("Outfit-Light", size: 10))
                .foregroundColor(good ? Color(hex: "#3D2B2E") : Color(hex: "#B8A9AB"))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }

    // MARK: - Screen 2: Q1 Procedure

    private var procedureScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            questionTopBar(step: 1, total: 3)

            Text("Your procedure")
                .font(.custom("Outfit-SemiBold", size: 9))
                .foregroundColor(Color(hex: "#C4929A"))
                .tracking(3)
                .textCase(.uppercase)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            (
                Text("What did you\n")
                    .font(.system(size: 23, weight: .regular, design: .serif))
                +
                Text("have done?")
                    .font(.system(size: 23, weight: .regular, design: .serif))
            )
            .foregroundColor(Color(hex: "#3D2B2E"))
            .lineSpacing(2)
            .padding(.horizontal, 18)
            .padding(.bottom, 6)

            Text("We'll build your personalised recovery timeline from this.")
                .font(.custom("Outfit-Light", size: 11))
                .foregroundColor(Color(hex: "#B8A9AB"))
                .lineSpacing(3)
                .padding(.horizontal, 18)
                .padding(.bottom, 22)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 9) {
                    ForEach(ProcedureOption.allCases) { option in
                        optionPill(
                            icon: option.icon,
                            title: option.rawValue,
                            desc: option.optionDescription,
                            isSelected: selectedProcedure == option
                        ) {
                            withAnimation(.spring(response: 0.3)) { selectedProcedure = option }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }

            primaryButton(label: "Continue →", enabled: selectedProcedure != nil, gradient: false) {
                withAnimation { screen = 2 }
            }
            Spacer().frame(height: 14)
        }
    }

    // MARK: - Screen 3: Q2 When

    private var whenScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            questionTopBar(step: 2, total: 3)

            Text("Your timing")
                .font(.custom("Outfit-SemiBold", size: 9))
                .foregroundColor(Color(hex: "#C4929A"))
                .tracking(3)
                .textCase(.uppercase)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            (
                Text("When did it\n")
                    .font(.system(size: 23, weight: .regular, design: .serif))
                +
                Text("happen?")
                    .font(.system(size: 23, weight: .regular, design: .serif))
            )
            .foregroundColor(Color(hex: "#3D2B2E"))
            .lineSpacing(2)
            .padding(.horizontal, 18)
            .padding(.bottom, 6)

            Text("This helps us find where you are in your recovery right now.")
                .font(.custom("Outfit-Light", size: 11))
                .foregroundColor(Color(hex: "#B8A9AB"))
                .lineSpacing(3)
                .padding(.horizontal, 18)
                .padding(.bottom, 22)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 9) {
                    ForEach(WhenOption.allCases) { option in
                        whenPill(option)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }

            primaryButton(label: "Continue →", enabled: selectedWhen != nil, gradient: false) {
                if let proc = selectedProcedure, let when = selectedWhen {
                    OnboardingStore.save(procedureName: proc.storedName, procedureDate: when.procedureDate)
                }
                withAnimation { screen = 3 }
            }
            Spacer().frame(height: 14)
        }
    }

    // MARK: - Screen 4: Recovery Projection

    private var projectionScreen: some View {
        let proc = selectedProcedure ?? .rhinoplasty
        let nodes = proc.timelineNodes
        let dayNum = daysSinceProcedure + 1
        let dayBadge = dayNum <= 14 ? "Day \(dayNum)" : "Week \(dayNum / 7)"

        return VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 14)

            // "Your Recovery Plan" badge
            HStack(spacing: 5) {
                Circle().fill(Color(hex: "#8E4C5C")).frame(width: 5, height: 5)
                Text("Your Recovery Plan")
                    .font(.custom("Outfit-Bold", size: 9))
                    .foregroundColor(Color(hex: "#8E4C5C"))
                    .tracking(1.5)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 11).padding(.vertical, 5)
            .background(Color(hex: "#8E4C5C").opacity(0.10))
            .clipShape(Capsule())
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            // Headline
            (
                Text("Your \(proc.storedName)\n")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(Color(hex: "#3D2B2E"))
                +
                Text("timeline is ready.")
                    .font(.system(size: 22, weight: .light, design: .serif))
                    .italic()
                    .foregroundColor(Color(hex: "#8E4C5C"))
            )
            .lineSpacing(2)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            Text("Based on your procedure and timing. Your journal will track where you are day by day.")
                .font(.custom("Outfit-Light", size: 10))
                .foregroundColor(Color(hex: "#B8A9AB"))
                .lineSpacing(2)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    // Timeline card
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack {
                            Text("\(proc.storedName)")
                                .font(.custom("Outfit-SemiBold", size: 11))
                                .foregroundColor(Color(hex: "#3D2B2E"))
                            Spacer()
                            Text("\(dayBadge) ✦")
                                .font(.custom("Outfit-Bold", size: 9))
                                .foregroundColor(.white)
                                .tracking(0.5)
                                .padding(.horizontal, 9).padding(.vertical, 3)
                                .background(Color(hex: "#8E4C5C"))
                                .clipShape(Capsule())
                        }
                        .padding(.bottom, 14)

                        // Vertical timeline
                        ZStack(alignment: .topLeading) {
                            LinearGradient(
                                colors: [Color(hex: "#8E4C5C"), Color(hex: "#C4929A").opacity(0.2)],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(width: 1.5)
                            .padding(.leading, 5.25)
                            .padding(.vertical, 6)

                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(nodes.indices, id: \.self) { i in
                                    timelineNode(nodes[i])
                                        .padding(.bottom, i < nodes.count - 1 ? 10 : 0)
                                }
                            }
                            .padding(.leading, 14)
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#C4929A").opacity(0.18), lineWidth: 1))
                    .shadow(color: Color(hex: "#8E4C5C").opacity(0.12), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)

                    // Pink note
                    HStack(spacing: 6) {
                        Text("📸")
                            .font(.system(size: 12))
                        Text("We'll prompt you to log photos at the right moments — so you never miss a milestone.")
                            .font(.custom("Outfit-Light", size: 10))
                            .foregroundColor(Color(hex: "#8E4C5C"))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#f8e9ef"), Color(hex: "#f0d4dc")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#C4929A").opacity(0.25), lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                }
            }

            primaryButton(label: "This looks right →", enabled: true, gradient: true) {
                withAnimation { screen = 4 }
            }
            Spacer().frame(height: 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timelineNode(_ node: (time: String, desc: String, isCurrent: Bool)) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                if node.isCurrent {
                    Circle().stroke(Color(hex: "#8E4C5C").opacity(0.2), lineWidth: 3).frame(width: 18, height: 18)
                    Circle().fill(Color(hex: "#8E4C5C")).frame(width: 12, height: 12)
                } else {
                    Circle().fill(Color.white).frame(width: 12, height: 12)
                    Circle().stroke(Color(hex: "#C4929A").opacity(0.18), lineWidth: 2).frame(width: 12, height: 12)
                }
            }
            .frame(width: 18, alignment: .center)
            .padding(.top, 2)
            .zIndex(2)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.time)
                    .font(.custom("Outfit-Bold", size: 9))
                    .foregroundColor(node.isCurrent ? Color(hex: "#8E4C5C") : Color(hex: "#B8A9AB"))
                    .tracking(0.8)
                    .textCase(.uppercase)
                Text(node.desc)
                    .font(.custom("Outfit-Light", size: 10.5))
                    .foregroundColor(node.isCurrent ? Color(hex: "#3D2B2E") : Color(hex: "#B8A9AB"))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var daysSinceProcedure: Int {
        let cal = Calendar.current
        let date = selectedWhen?.procedureDate ?? Date()
        return max(0, cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day ?? 0)
    }

    // MARK: - Screen 5: Social Proof

    private var socialProofScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 14)

            Text("The difference it makes")
                .font(.custom("Outfit-SemiBold", size: 9))
                .foregroundColor(Color(hex: "#C4929A"))
                .tracking(3)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            (
                Text("Trackers vs.\n")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(Color(hex: "#3D2B2E"))
                +
                Text("non-trackers.")
                    .font(.system(size: 22, weight: .light, design: .serif))
                    .italic()
                    .foregroundColor(Color(hex: "#8E4C5C"))
            )
            .lineSpacing(2)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            Text("Real outcomes from patients who documented their recovery from day one.")
                .font(.custom("Outfit-Light", size: 10.5))
                .foregroundColor(Color(hex: "#B8A9AB"))
                .lineSpacing(2)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    // Quote card
                    VStack(alignment: .leading, spacing: 7) {
                        Text("\"My surgeon told me it takes a full year to see the final result. I had no idea what 'normal' looked like week by week — logging photos gave me something to actually reference at every check-up.\"")
                            .font(.custom("Outfit-Light", size: 10.5))
                            .italic()
                            .foregroundColor(Color(hex: "#3D2B2E"))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: "#C4929A").opacity(0.14))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "#C4929A"))
                                )
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Maya R. · Beta user")
                                    .font(.custom("Outfit-SemiBold", size: 9.5))
                                    .foregroundColor(Color(hex: "#8E4C5C"))
                                Text("Rhinoplasty · 4 months post-op")
                                    .font(.custom("Outfit-Light", size: 9))
                                    .foregroundColor(Color(hex: "#B8A9AB"))
                            }
                        }
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#f8e9ef"), Color(hex: "#f0d2da")],
                            startPoint: UnitPoint(x: 0.14, y: 0),
                            endPoint: UnitPoint(x: 0.86, y: 1)
                        )
                    )
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#C4929A").opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                }
            }

            primaryButton(label: "I'm ready →", enabled: true, gradient: false) {
                withAnimation { screen = 5 }
            }
            Spacer().frame(height: 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statCard(number: String, title: String, desc: String) -> some View {
        HStack(alignment: .center, spacing: 13) {
            Text(number)
                .font(.system(size: 32, weight: .medium, design: .serif))
                .foregroundColor(Color(hex: "#8E4C5C"))
                .frame(minWidth: 54, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Outfit-SemiBold", size: 11.5))
                    .foregroundColor(Color(hex: "#3D2B2E"))
                    .lineSpacing(1)
                Text(desc)
                    .font(.custom("Outfit-Light", size: 9.5))
                    .foregroundColor(Color(hex: "#B8A9AB"))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#C4929A").opacity(0.18), lineWidth: 1))
        .shadow(color: Color(hex: "#8E4C5C").opacity(0.07), radius: 6, x: 0, y: 2)
    }

    // MARK: - Screen 6: Paywall

    private var paywallScreen: some View {
        VStack(spacing: 0) {
            // Gradient hero
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [Color(hex: "#6B3346"), Color(hex: "#8E4C5C"), Color(hex: "#B76E79")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(maxWidth: .infinity)

                // Decorative circles
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 180, height: 180)
                    .offset(x: UIScreen.main.bounds.width - 60, y: -50)
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 110, height: 110)
                    .offset(x: UIScreen.main.bounds.width - 20, y: 0)

                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 52)

                    HStack(spacing: 5) {
                        Text("⭑ Founding member — 40% off")
                            .font(.custom("Outfit-SemiBold", size: 8.5))
                            .foregroundColor(.white)
                            .tracking(1)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.white.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: 100).stroke(Color.white.opacity(0.24), lineWidth: 1))
                    .clipShape(Capsule())
                    .padding(.bottom, 10)

                    Text("Your journal awaits")
                        .font(.custom("Outfit-Regular", size: 9))
                        .foregroundColor(Color.white.opacity(0.6))
                        .tracking(2)
                        .textCase(.uppercase)
                        .padding(.bottom, 5)

                    Text("Start your recovery\njournal today.")
                        .font(.system(size: 24, weight: .regular, design: .serif))
                        .foregroundColor(.white)
                        .lineSpacing(2)
                        .padding(.bottom, 4)

                    Text("Your personalised timeline is set up and ready to track.")
                        .font(.custom("Outfit-Light", size: 10.5))
                        .foregroundColor(Color.white.opacity(0.68))
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
            .clipped()

            // Body
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 14)

                    // Plan options
                    VStack(spacing: 7) {
                        planCard(
                            name: "Annual",
                            price: paymentVM.annualPriceInfo?.displayPrice ?? "—",
                            subtitle: "All benefits of Gold at a discounted price for 12 months",
                            isSelected: selectedPlan == 0,
                            badge: "Best Value",
                            isLoading: paymentVM.isFetchingPrices && paymentVM.annualPriceInfo == nil
                        ) { selectedPlan = 0 }

                        planCard(
                            name: "Gold",
                            price: paymentVM.goldPriceInfo?.displayPrice ?? "—",
                            isSelected: selectedPlan == 1,
                            badge: nil,
                            perks: ["75 msgs", "15 imgs", "210 credits"],
                            isLoading: paymentVM.isFetchingPrices && paymentVM.goldPriceInfo == nil
                        ) { selectedPlan = 1 }

                        planCard(
                            name: "Silver",
                            price: paymentVM.silverPriceInfo?.displayPrice ?? "—",
                            isSelected: selectedPlan == 2,
                            badge: nil,
                            perks: ["30 msgs", "5 imgs", "80 credits"],
                            isLoading: paymentVM.isFetchingPrices && paymentVM.silverPriceInfo == nil
                        ) { selectedPlan = 2 }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .task { await paymentVM.fetchPrices() }

                    // Benefits
                    VStack(spacing: 7) {
                        benefitRow(bold: "24/7 personal AI concierge", rest: " — always here to guide your recovery")
                        benefitRow(bold: "Week-by-week healing", rest: " with guided daily photo prompts")
                        benefitRow(bold: "Know when to rebook", rest: " — never guess your timing again")
                        benefitRow(bold: "Build a record", rest: " your provider can actually reference")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                    // Email input
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Email")
                            .font(.custom("Outfit-Medium", size: 9))
                            .foregroundColor(Color(hex: "#8E4C5C"))
                            .tracking(1.5)
                            .textCase(.uppercase)

                        TextField("your@email.com", text: $email)
                            .font(.custom("Outfit-Regular", size: 13))
                            .foregroundColor(Color(hex: "#3D2B2E"))
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isValidEmail ? Color(hex: "#8E4C5C").opacity(0.35) : Color(hex: "#C4929A").opacity(0.25),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                    // Payment error
                    if let error = paymentError {
                        Text(error)
                            .font(.custom("Outfit-Light", size: 10))
                            .foregroundColor(Color(hex: "#C0392B"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }

                    // Main CTA
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
                                Text("Start My Recovery Journal")
                                    .font(.custom("Outfit-SemiBold", size: 13))
                                    .foregroundColor(.white)
                                    .tracking(0.3)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            Group {
                                if isValidEmail && !isProcessingPayment {
                                    LinearGradient(
                                        colors: [Color(hex: "#6B3346"), Color(hex: "#8E4C5C"), Color(hex: "#B76E79")],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                } else {
                                    LinearGradient(
                                        colors: [Color(hex: "#8E4C5C").opacity(0.35), Color(hex: "#8E4C5C").opacity(0.35)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                }
                            }
                        )
                        .cornerRadius(13)
                        .shadow(
                            color: isValidEmail ? Color(hex: "#6B3346").opacity(0.32) : Color.clear,
                            radius: 8, x: 0, y: 5
                        )
                    }
                    .disabled(!isValidEmail || isProcessingPayment)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    if !isProcessingPayment {
                    VStack(spacing: 4) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#8E4C5C"))
                            Text("100% money back if you haven't used any AI credits")
                                .font(.custom("Outfit-SemiBold", size: 11.5))
                                .foregroundColor(Color(hex: "#3D2B2E"))
                        }
                        Text("Cancel anytime. No questions asked.")
                            .font(.custom("Outfit-Light", size: 10.5))
                            .foregroundColor(Color(hex: "#B8A9AB"))
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    } // end if !isProcessingPayment

                    Button {
                        OnboardingStore.hasCompleted = true
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onSignIn() }
                    } label: {
                        Text("Already have an account? Sign In")
                            .font(.custom("Outfit-Regular", size: 12))
                            .foregroundColor(Color(hex: "#B8A9AB"))
                            .underline()
                    }
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Shared Components

    private func questionTopBar(step: Int, total: Int) -> some View {
        HStack(spacing: 10) {
            Button { withAnimation { screen -= 1 } } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                        .shadow(color: Color(hex: "#8E4C5C").opacity(0.07), radius: 5, x: 0, y: 2)
                    Circle()
                        .stroke(Color(hex: "#C4929A").opacity(0.18), lineWidth: 1)
                        .frame(width: 30, height: 30)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#8E4C5C"))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#C4929A").opacity(0.2)).frame(height: 3)
                    Capsule()
                        .fill(Color(hex: "#8E4C5C"))
                        .frame(width: geo.size.width * CGFloat(step) / CGFloat(total), height: 3)
                }
            }
            .frame(height: 3)

            Text("\(step) of \(total)")
                .font(.custom("Outfit-Medium", size: 9))
                .foregroundColor(Color(hex: "#B8A9AB"))
                .fixedSize()
        }
        .padding(.horizontal, 18)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }

    private func optionPill(icon: String, title: String, desc: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                // Rounded-rect icon (not circle)
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#8E4C5C").opacity(isSelected ? 0.15 : 0.10))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#8E4C5C"))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.custom("Outfit-SemiBold", size: 12))
                        .foregroundColor(Color(hex: "#3D2B2E"))
                    Text(desc)
                        .font(.custom("Outfit-Light", size: 10))
                        .foregroundColor(Color(hex: "#B8A9AB"))
                }

                Spacer()

                // Circle check
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "#8E4C5C") : Color.clear)
                        .frame(width: 18, height: 18)
                    Circle()
                        .stroke(isSelected ? Color(hex: "#8E4C5C") : Color(hex: "#C4929A").opacity(0.18), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                isSelected
                    ? LinearGradient(colors: [Color(hex: "#f8e9ef"), Color(hex: "#f0d4dc")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [.white, .white], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(13)
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(isSelected ? Color(hex: "#8E4C5C").opacity(0.35) : Color(hex: "#C4929A").opacity(0.18), lineWidth: 1.5)
            )
            .shadow(color: Color(hex: "#8E4C5C").opacity(0.07), radius: 6, x: 0, y: 2)
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
                    .font(.custom("Outfit-Regular", size: 12.5))
                    .foregroundColor(Color(hex: "#3D2B2E").opacity(isSelected ? 1 : 0.7))
                Spacer()
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "#8E4C5C") : Color.clear)
                        .frame(width: 18, height: 18)
                    Circle()
                        .stroke(isSelected ? Color(hex: "#8E4C5C") : Color(hex: "#C4929A").opacity(0.18), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                isSelected
                    ? LinearGradient(colors: [Color(hex: "#f8e9ef"), Color(hex: "#f0d4dc")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [.white, .white], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(13)
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(isSelected ? Color(hex: "#8E4C5C").opacity(0.35) : Color(hex: "#C4929A").opacity(0.18), lineWidth: 1.5)
            )
            .shadow(color: Color(hex: "#8E4C5C").opacity(0.07), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func planCard(name: String, price: String, subtitle: String? = nil, isSelected: Bool, badge: String?, perks: [String] = [], isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "#8E4C5C") : Color.clear)
                        .frame(width: 16, height: 16)
                    Circle()
                        .stroke(isSelected ? Color(hex: "#8E4C5C") : Color(hex: "#C4929A").opacity(0.18), lineWidth: 2)
                        .frame(width: 16, height: 16)
                    if isSelected {
                        Circle().fill(Color.white).frame(width: 5, height: 5)
                    }
                }
                .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.custom("Outfit-Bold", size: 12))
                            .foregroundColor(Color(hex: "#3D2B2E"))
                        if let badge = badge {
                            Text(badge)
                                .font(.custom("Outfit-Bold", size: 8))
                                .foregroundColor(.white)
                                .tracking(0.5)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color(hex: "#8E4C5C"))
                                .clipShape(Capsule())
                        }
                    }
                    if isLoading {
                        Capsule()
                            .fill(Color(hex: "#C4929A").opacity(0.15))
                            .frame(width: 72, height: 8)
                    } else {
                        Text(price)
                            .font(.custom("Outfit-Light", size: 10))
                            .foregroundColor(isSelected ? Color(hex: "#8E4C5C") : Color(hex: "#B8A9AB"))
                    }
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.custom("Outfit-Light", size: 9.5))
                            .foregroundColor(isSelected ? Color(hex: "#8E4C5C").opacity(0.75) : Color(hex: "#B8A9AB").opacity(0.85))
                            .lineSpacing(1.5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !perks.isEmpty {
                        HStack(spacing: 0) {
                            ForEach(Array(perks.enumerated()), id: \.offset) { idx, perk in
                                Text(perk)
                                    .font(.custom("Outfit-Light", size: 9))
                                    .foregroundColor(isSelected ? Color(hex: "#8E4C5C").opacity(0.7) : Color(hex: "#B8A9AB").opacity(0.85))
                                if idx < perks.count - 1 {
                                    Text("  ·  ")
                                        .font(.custom("Outfit-Light", size: 9))
                                        .foregroundColor(isSelected ? Color(hex: "#8E4C5C").opacity(0.4) : Color(hex: "#C4929A").opacity(0.45))
                                }
                            }
                        }
                        .padding(.top, 1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 13).padding(.vertical, 11)
            .background(
                isSelected
                    ? LinearGradient(colors: [Color(hex: "#f8e9ef"), Color(hex: "#f0d4dc")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [.white, .white], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(13)
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(isSelected ? Color(hex: "#8E4C5C").opacity(0.35) : Color(hex: "#C4929A").opacity(0.18), lineWidth: 1.5)
            )
            .shadow(color: Color(hex: "#8E4C5C").opacity(0.07), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func benefitRow(bold: String, rest: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color(hex: "#8E4C5C"))
                .frame(width: 16)
            (
                Text(bold).font(.custom("Outfit-SemiBold", size: 10.5))
                + Text(rest).font(.custom("Outfit-Light", size: 10.5))
            )
            .foregroundColor(Color(hex: "#3D2B2E"))
            .lineSpacing(2)
        }
    }

    private func primaryButton(label: String, enabled: Bool, gradient: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("Outfit-SemiBold", size: 12.5))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    if !enabled {
                        Color(hex: "#8E4C5C").opacity(0.35).cornerRadius(13)
                    } else if gradient {
                        LinearGradient(
                            colors: [Color(hex: "#6B3346"), Color(hex: "#8E4C5C"), Color(hex: "#B76E79")],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .cornerRadius(13)
                    } else {
                        Color(hex: "#8E4C5C").cornerRadius(13)
                    }
                }
                .shadow(color: enabled ? Color(hex: "#8E4C5C").opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .disabled(!enabled)
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }
}

#Preview {
    OnboardingFlowView()
}
