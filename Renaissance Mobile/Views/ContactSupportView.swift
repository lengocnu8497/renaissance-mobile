//
//  ContactSupportView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI

struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundProfile
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        // Contact Section
                        contactSection
                            .padding(.top, Theme.Spacing.xl)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
            }
            .navigationTitle("Contact Support")
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

    // MARK: - Contact Section
    private var contactSection: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Header Text
            VStack(spacing: Theme.Spacing.md) {
                Text("How can we help you?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.Colors.textProfilePrimary)
                    .multilineTextAlignment(.center)

                Text("Choose your preferred way to reach us")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.xs)

            // Contact Buttons
            VStack(spacing: Theme.Spacing.lg) {
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

                // Call Us Button
                Button(action: {
                    // Handle phone call
                }) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.Colors.primaryProfile)

                        Text("Call us")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.Colors.primaryProfile)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.Colors.primaryProfile.opacity(0.15))
                    .cornerRadius(Theme.CornerRadius.large)
                }
            }

            // Additional Info
            VStack(spacing: Theme.Spacing.sm) {
                Text("Support Hours")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.textProfilePrimary)

                Text("Monday - Friday: 9:00 AM - 6:00 PM EST")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                Text("Saturday - Sunday: 10:00 AM - 4:00 PM EST")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Theme.Spacing.lg)
        }
    }
}

#Preview {
    ContactSupportView()
}
