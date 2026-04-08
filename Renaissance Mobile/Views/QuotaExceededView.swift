//
//  QuotaExceededView.swift
//  Renaissance Mobile
//
//  Paywall shown when user exceeds quota.
//  Visual design mirrors the onboarding paywall.
//

import SwiftUI

private enum PaywallUI {
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
    static let roseDeep = Color(hex: "#976769")
    static let border = Color.white.opacity(0.72)
    static let shadow = Color(red: 90/255, green: 103/255, blue: 80/255).opacity(0.10)
}

struct QuotaExceededView: View {
    let reason: String
    var weeklyPrice: String = "..."
    var monthlyPrice: String = "..."
    var yearlyPrice: String = "..."
    let onUpgrade: (SubscriptionTier) async -> Void
    let onDismiss: () -> Void

    @State private var selectedPlan: SubscriptionTier = .yearly
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 12)
                    planCards
                    unlocks
                    actions
                }
                .padding(.bottom, 18)
            }
        }
        .background(PaywallUI.bg.ignoresSafeArea())
    }

    private var yearlySupportText: String {
        yearlyPrice == "..." ? "Billed yearly" : "About $17.99/mo billed yearly"
    }

    private func planPerks(for tier: SubscriptionTier) -> [String] {
        switch tier {
        case .yearly, .monthly:
            return ["210 AI credits"]
        case .weekly:
            return ["80 AI credits"]
        }
    }

    private func planDescription(for tier: SubscriptionTier) -> String {
        switch tier {
        case .yearly:
            return "Everything in Monthly at the strongest long-term value."
        case .monthly:
            return "For consistent support across chat, research, and journal."
        case .weekly:
            return "A lighter starting point for occasional AI help."
        }
    }

    private var selectedPlanPrice: String {
        switch selectedPlan {
        case .yearly: return yearlyPrice
        case .monthly: return monthlyPrice
        case .weekly: return weeklyPrice
        }
    }

    private func planUnit(for tier: SubscriptionTier) -> String {
        switch tier {
        case .yearly: return "/yr"
        case .weekly: return "/wk"
        case .monthly: return "/mo"
        }
    }

    private func priceDisplay(_ rawPrice: String, tier: SubscriptionTier) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(
                rawPrice == "..." ? "..." : rawPrice
                    .replacingOccurrences(of: "/yr", with: "")
                    .replacingOccurrences(of: "/mo", with: "")
                    .replacingOccurrences(of: "/wk", with: "")
            )
                .font(.custom("Manrope", size: tier == .yearly ? 30 : 27))
                .fontWeight(.bold)
                .foregroundColor(PaywallUI.primaryInk)
            Text(planUnit(for: tier))
                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                .foregroundColor(PaywallUI.muted)
                .padding(.leading, 2)
        }
    }

    private func selectionDot(for tier: SubscriptionTier) -> some View {
        let isSelected = selectedPlan == tier
        return ZStack {
            Circle()
                .stroke(isSelected ? PaywallUI.primary : Color.black.opacity(0.10), lineWidth: 2)
                .frame(width: 18, height: 18)
            if isSelected {
                Circle()
                    .fill(PaywallUI.primary)
                    .frame(width: 18, height: 18)
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var groupedUnlocksSurface: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(PaywallUI.card)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            HStack {
                Color.clear
                    .frame(width: 40, height: 40)
                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(PaywallUI.primaryInk)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.82))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(PaywallUI.border, lineWidth: 1)
                        )
                }
            }

            Text("Unlock the full experience")
                .font(.custom("Manrope", size: 29))
                .fontWeight(.heavy)
                .foregroundColor(PaywallUI.primaryInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 56)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        VStack(spacing: 7) {
            featuredAnnualCard
            compactPlanCard(name: "Monthly", price: monthlyPrice, tier: .monthly)
            compactPlanCard(name: "Weekly", price: weeklyPrice, tier: .weekly)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    // MARK: - Unlocks

    private var unlocks: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What your plan unlocks")
                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                .tracking(2.3)
                .foregroundColor(PaywallUI.muted)
                .textCase(.uppercase)

            VStack(spacing: 10) {
                unlockCard(
                    icon: "ellipsis.message",
                    tint: PaywallUI.primarySoft,
                    iconColor: PaywallUI.primary,
                    title: "Continue Ask Rena without interruptions",
                    body: "Stay in the same conversation and keep asking follow-up questions."
                )
                unlockCard(
                    icon: "chart.line.text.clipboard",
                    tint: PaywallUI.roseSoft,
                    iconColor: PaywallUI.roseDeep,
                    title: "Turn your history into better guidance",
                    body: "Use research, journal trends, and AI summaries together in one place."
                )
                unlockCard(
                    icon: "bookmark",
                    tint: PaywallUI.roseSoft.opacity(0.9),
                    iconColor: PaywallUI.roseDeep,
                    title: "Get more value from every saved procedure",
                    body: "Keep notes, questions, and chat pathways attached to what you save."
                )
            }
        }
        .padding(16)
        .background(groupedUnlocksSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(PaywallUI.roseSoft.opacity(0.8), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: PaywallUI.shadow.opacity(0.75), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    isProcessing = true
                    await onUpgrade(selectedPlan)
                    isProcessing = false
                }
            } label: {
                Group {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Upgrade Now")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                            .foregroundColor(.white)
                            .tracking(0.3)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(PaywallUI.primary)
                .cornerRadius(24)
                .shadow(color: PaywallUI.shadow, radius: 10, x: 0, y: 5)
            }
            .disabled(isProcessing)
            .padding(.horizontal, 16)

            if !isProcessing {
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(PaywallUI.roseDeep)
                        Text("100% money back")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                            .foregroundColor(PaywallUI.roseDeep)
                            .multilineTextAlignment(.center)
                    }
                    Text("Cancel anytime. No questions asked.")
                        .font(.custom("PlusJakartaSans-Regular", size: 11))
                        .foregroundColor(PaywallUI.muted)
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
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                Button(action: onDismiss) {
                    Text("Maybe Later")
                        .font(.custom("PlusJakartaSans-Medium", size: 14))
                        .foregroundColor(PaywallUI.muted)
                        .underline()
                }
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Helpers

    private var featuredAnnualCard: some View {
        let isSelected = selectedPlan == .yearly
        return Button { selectedPlan = .yearly } label: {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Annual")
                                .font(.custom("Manrope", size: 24))
                                .fontWeight(.bold)
                                .foregroundColor(PaywallUI.primaryInk)
                            Text("Best Value")
                                .font(.custom("PlusJakartaSans-Bold", size: 10))
                                .foregroundColor(.white)
                                .tracking(1.3)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(PaywallUI.rose)
                                .clipShape(Capsule())
                        }
                        Text(planDescription(for: .yearly))
                            .font(.custom("PlusJakartaSans-Regular", size: 13))
                            .foregroundColor(PaywallUI.muted)
                            .lineSpacing(3)
                    }

                    Spacer()
                    selectionDot(for: .yearly)
                        .padding(.top, 2)
                }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        priceDisplay(yearlyPrice, tier: .yearly)
                        Text(yearlySupportText)
                            .font(.custom("PlusJakartaSans-Regular", size: 11))
                            .foregroundColor(PaywallUI.roseDeep)
                    }

                    Spacer(minLength: 10)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Includes")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                            .tracking(1.6)
                            .foregroundColor(PaywallUI.muted)
                            .textCase(.uppercase)
                        Text(planPerks(for: .yearly).joined(separator: " • "))
                            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                            .foregroundColor(PaywallUI.primaryInk)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(PaywallUI.roseSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(16)
            .background(isSelected ? PaywallUI.surface : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(isSelected ? PaywallUI.rose.opacity(0.38) : Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: PaywallUI.shadow.opacity(0.85), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func compactPlanCard(name: String, price: String, tier: SubscriptionTier) -> some View {
        let isSelected = selectedPlan == tier
        return Button { selectedPlan = tier } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.custom("Manrope", size: 23))
                            .fontWeight(.bold)
                            .foregroundColor(PaywallUI.primaryInk)
                        Text(planDescription(for: tier))
                            .font(.custom("PlusJakartaSans-Regular", size: 13))
                            .foregroundColor(PaywallUI.muted)
                            .lineSpacing(3)
                    }
                    Spacer()
                    selectionDot(for: tier)
                        .padding(.top, 2)
                }

                HStack(alignment: .lastTextBaseline) {
                    priceDisplay(price, tier: tier)
                    Spacer()
                    Text(planPerks(for: tier).joined(separator: " • "))
                        .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                        .foregroundColor(PaywallUI.muted)
                }
            }
            .padding(15)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(isSelected ? PaywallUI.rose.opacity(0.45) : PaywallUI.roseSoft.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: PaywallUI.shadow.opacity(0.65), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func unlockCard(icon: String, tint: some ShapeStyle, iconColor: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(iconColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                    .foregroundColor(PaywallUI.primaryInk)
                Text(body)
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundColor(PaywallUI.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(PaywallUI.roseSoft.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: PaywallUI.shadow.opacity(0.6), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    QuotaExceededView(
        reason: "You've reached your monthly AI credit limit.",
        weeklyPrice: "$14.99/wk",
        monthlyPrice: "$29.99/mo",
        yearlyPrice: "$215.99/yr",
        onUpgrade: { _ in },
        onDismiss: {}
    )
}
