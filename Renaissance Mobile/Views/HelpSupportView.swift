//
//  HelpSupportView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI

struct HelpSupportView: View {
    @State private var showPricingPaywall = false

    private let supportURL = URL(string: "https://renaesthetic.com/support")!

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundProfile
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        // FAQ Section
                        faqSection
                            .padding(.top, Theme.Spacing.lg)

                        // Contact Section
                        contactSection

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .forceUIKitNavigationBarHidden()
            .fullScreenCover(isPresented: $showPricingPaywall) {
                SubscriptionPaywallView(
                    onDismiss: { showPricingPaywall = false },
                    showsPurchaseCTA: false,
                    showsRestoreButton: false
                )
            }
        }
    }

    // MARK: - FAQ Section
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Frequently Asked Questions")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Theme.Colors.textProfilePrimary)
                .padding(.horizontal, Theme.Spacing.xs)

            VStack(spacing: Theme.Spacing.lg) {
                FAQItemView(
                    section: .payments,
                    onTap: {
                        showPricingPaywall = true
                    }
                )

                FAQItemView(
                    section: .account,
                    onTap: {
                        UIApplication.shared.open(AppConfig.privacyPolicyURL)
                    }
                )
            }
        }
    }

    // MARK: - Contact Section
    private var contactSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Can't find what you're looking for?")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.Colors.textProfilePrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xs)

            // Contact Support Button
            Button(action: {
                UIApplication.shared.open(supportURL)
            }) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)

                    Text("Contact Support")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Theme.Colors.primaryProfile)
                .cornerRadius(Theme.CornerRadius.large)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - FAQ Section Enum
enum FAQSection: String, CaseIterable {
    case payments = "Pricing"
    case account = "Account & Privacy"
}

// MARK: - FAQ Item View
struct FAQItemView: View {
    let section: FAQSection
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(section.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.Colors.textProfilePrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.lg)
            .background(Color.white)
            .cornerRadius(Theme.CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .stroke(Theme.Colors.borderLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HelpSupportView()
}
