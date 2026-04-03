//
//  QuotaExceededView.swift
//  Renaissance Mobile
//
//  Paywall shown when user exceeds quota.
//  Visual design mirrors the onboarding paywall.
//

import SwiftUI

struct QuotaExceededView: View {
    let reason: String
    var silverPrice: String = "..."
    var goldPrice: String = "..."
    var annualPrice: String = "..."
    let onUpgrade: (SubscriptionTier) async -> Void
    let onDismiss: () -> Void

    @State private var selectedPlan: SubscriptionTier = .gold
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 0) {
            hero
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 14)
                    planCards
                    benefits
                    actions
                }
            }
        }
        .background(Color(hex: "#FFF8F6").ignoresSafeArea())
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(hex: "#6B3346"), Color(hex: "#8E4C5C"), Color(hex: "#B76E79")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(maxWidth: .infinity)

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

                Text("✦ Unlock your full recovery")
                    .font(.custom("Outfit-SemiBold", size: 8.5))
                    .foregroundColor(.white)
                    .tracking(1)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.white.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: 100).stroke(Color.white.opacity(0.24), lineWidth: 1))
                    .clipShape(Capsule())
                    .padding(.bottom, 10)

                Text("You've reached your limit")
                    .font(.custom("Outfit-Regular", size: 9))
                    .foregroundColor(Color.white.opacity(0.6))
                    .tracking(2)
                    .textCase(.uppercase)
                    .padding(.bottom, 5)

                Text("Continue your\nrecovery journey.")
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .foregroundColor(.white)
                    .lineSpacing(2)
                    .padding(.bottom, 4)

                Text(reason)
                    .font(.custom("Outfit-Light", size: 10.5))
                    .foregroundColor(Color.white.opacity(0.68))
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
        }
        .clipped()
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        VStack(spacing: 7) {
            planCard(
                name: "Annual",
                price: annualPrice,
                subtitle: "All benefits of Gold at a discounted price for 12 months",
                tier: .annual,
                badge: "Best Value"
            )
            planCard(
                name: "Gold",
                price: goldPrice,
                tier: .gold,
                perks: ["75 msgs", "15 imgs", "210 credits"]
            )
            planCard(
                name: "Silver",
                price: silverPrice,
                tier: .silver,
                perks: ["30 msgs", "5 imgs", "80 credits"]
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(spacing: 7) {
            benefitRow(bold: "24/7 personal AI concierge", rest: " — always here to guide your recovery")
            benefitRow(bold: "Week-by-week healing", rest: " with guided daily photo prompts")
            benefitRow(bold: "Know when to rebook", rest: " — never guess your timing again")
            benefitRow(bold: "Build a record", rest: " your provider can actually reference")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 8) {
            // Upgrade Now
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
                            .font(.custom("Outfit-SemiBold", size: 13))
                            .foregroundColor(.white)
                            .tracking(0.3)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#6B3346"), Color(hex: "#8E4C5C"), Color(hex: "#B76E79")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .cornerRadius(13)
                .shadow(color: Color(hex: "#6B3346").opacity(0.32), radius: 8, x: 0, y: 5)
            }
            .disabled(isProcessing)
            .padding(.horizontal, 16)

            if !isProcessing {
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
                .padding(.bottom, 8)

                // Maybe Later
                Button(action: onDismiss) {
                    Text("Maybe Later")
                        .font(.custom("Outfit-Regular", size: 12))
                        .foregroundColor(Color(hex: "#B8A9AB"))
                        .underline()
                }
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Helpers

    private func planCard(name: String, price: String, subtitle: String? = nil, tier: SubscriptionTier, badge: String? = nil, perks: [String] = []) -> some View {
        let isSelected = selectedPlan == tier
        let isLoading = price == "..."
        return Button { selectedPlan = tier } label: {
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
                        if let badge {
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

                    if let subtitle {
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
}

#Preview {
    QuotaExceededView(
        reason: "You've reached your monthly AI credit limit.",
        silverPrice: "$14.99/mo",
        goldPrice: "$29.99/mo",
        annualPrice: "$215.99/yr",
        onUpgrade: { _ in },
        onDismiss: {}
    )
}
