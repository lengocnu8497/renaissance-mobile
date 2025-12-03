//
//  HelpSupportView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI

struct HelpSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedSection: FAQSection? = nil

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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.Colors.textProfilePrimary)
                    }
                }
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
                    isExpanded: expandedSection == .payments,
                    onTap: {
                        withAnimation {
                            expandedSection = expandedSection == .payments ? nil : .payments
                        }
                    }
                )

                FAQItemView(
                    section: .procedures,
                    isExpanded: expandedSection == .procedures,
                    onTap: {
                        withAnimation {
                            expandedSection = expandedSection == .procedures ? nil : .procedures
                        }
                    }
                )

                FAQItemView(
                    section: .account,
                    isExpanded: expandedSection == .account,
                    onTap: {
                        withAnimation {
                            expandedSection = expandedSection == .account ? nil : .account
                        }
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

            // Chat with Support Button
            Button(action: {
                // Handle chat with support
            }) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.primaryProfile)

                    Text("Chat with support")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.Colors.primaryProfile)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Theme.Colors.primaryProfile.opacity(0.15))
                .cornerRadius(Theme.CornerRadius.large)
            }

            // Email Us Button
            Button(action: {
                // Handle email
            }) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.primaryProfile)

                    Text("Email us")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.Colors.primaryProfile)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Theme.Colors.primaryProfile.opacity(0.15))
                .cornerRadius(Theme.CornerRadius.large)
            }
        }
    }
}

// MARK: - FAQ Section Enum
enum FAQSection: String, CaseIterable {
    case payments = "Payments & Pricing"
    case procedures = "About Procedures"
    case account = "Account & Privacy"
}

// MARK: - FAQ Item View
struct FAQItemView: View {
    let section: FAQSection
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(section.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.Colors.textProfilePrimary)

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
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
    }
}

#Preview {
    HelpSupportView()
}
