//
//  SettingsView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 1/16/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var userProfile: UserProfile?
    @State private var isLoadingProfile = true
    @State private var showCancelConfirmation = false
    @State private var isCanceling = false
    @State private var showCancelSuccess = false
    @State private var showCancelError = false
    @State private var cancelErrorMessage = ""

    private let profileService = UserProfileService(supabase: supabase)
    private let subscriptionViewModel = SubscriptionViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundProfile
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        // Current Subscription Section
                        subscriptionSection

                        // Cancel Subscription Button
                        cancelSubscriptionButton
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.lg)
                }
            }
            .navigationTitle("Settings")
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
            .alert("Cancel Subscription", isPresented: $showCancelConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Confirm", role: .destructive) {
                    Task {
                        await cancelSubscription()
                    }
                }
            } message: {
                Text("Are you sure you want to cancel your subscription? You will lose access to premium features at the end of your billing period.")
            }
            .task {
                await loadProfile()
            }
        }
    }

    // MARK: - Profile Loading
    private func loadProfile() async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        do {
            let profile = try await profileService.getUserProfile()
            await MainActor.run {
                userProfile = profile
            }
        } catch {
            print("Failed to load profile: \(error.localizedDescription)")
        }
    }

    // MARK: - Subscription Section
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "SUBSCRIPTION")

            VStack(spacing: Theme.Spacing.lg) {
                if isLoadingProfile {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xl)
                } else {
                    // Current Plan
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Plan")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.textSecondary)

                            Text(planDisplayName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Theme.Colors.textProfilePrimary)
                        }

                        Spacer()

                        if userProfile?.billingPlan == .silver || userProfile?.billingPlan == .gold {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)

                    // Plan Details
                    if let plan = userProfile?.billingPlan, plan == .silver || plan == .gold {
                        Divider()
                            .padding(.horizontal, Theme.Spacing.lg)

                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            planDetailRow(icon: "message.fill", text: planMessages)
                            planDetailRow(icon: "photo.fill", text: planImages)
                            planDetailRow(icon: "sparkles", text: planCredits)
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.md)
                    }
                }
            }
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .stroke(Theme.Colors.borderLight, lineWidth: 1)
            )
        }
    }

    // MARK: - Cancel Subscription Button
    private var cancelSubscriptionButton: some View {
        VStack(spacing: Theme.Spacing.md) {
            if userProfile?.billingPlan == .silver || userProfile?.billingPlan == .gold {
                // Disclaimer note
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)

                        Text("If AI credits have been used, your subscription cancellation will take effect at the end of your current billing period.")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.small)
                }

                Button(action: {
                    showCancelConfirmation = true
                }) {
                    HStack(spacing: Theme.Spacing.sm) {
                        if isCanceling {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        } else {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 20))
                        }
                        Text(isCanceling ? "Canceling..." : "Cancel Subscription")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.medium)
                }
                .disabled(isCanceling)
            }
        }
        .alert("Subscription Canceled", isPresented: $showCancelSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your subscription has been canceled. You will continue to have access until the end of your billing period.")
        }
        .alert("Error", isPresented: $showCancelError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cancelErrorMessage)
        }
    }

    // MARK: - Helper Views
    private func planDetailRow(icon: String, text: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Computed Properties
    private var planDisplayName: String {
        guard let plan = userProfile?.billingPlan else { return "Free" }
        switch plan {
        case .free: return "Free"
        case .silver: return "Silver Plan"
        case .gold: return "Gold Plan"
        }
    }

    private var planMessages: String {
        guard let plan = userProfile?.billingPlan else { return "Limited messages" }
        switch plan {
        case .free: return "Limited messages"
        case .silver: return "30 messages per month"
        case .gold: return "75 messages per month"
        }
    }

    private var planImages: String {
        guard let plan = userProfile?.billingPlan else { return "No image uploads" }
        switch plan {
        case .free: return "No image uploads"
        case .silver: return "5 images per month"
        case .gold: return "15 images per month"
        }
    }

    private var planCredits: String {
        guard let plan = userProfile?.billingPlan else { return "No AI credits" }
        switch plan {
        case .free: return "No AI credits"
        case .silver: return "80 AI credits per month"
        case .gold: return "210 AI credits per month"
        }
    }

    // MARK: - Cancel Subscription
    private func cancelSubscription() async {
        isCanceling = true
        defer { isCanceling = false }

        let success = await subscriptionViewModel.cancelSubscription()

        if success {
            // Reload profile to reflect the updated status
            await loadProfile()
            showCancelSuccess = true
        } else {
            cancelErrorMessage = subscriptionViewModel.errorMessage ?? "Failed to cancel subscription. Please try again."
            showCancelError = true
        }
    }

    // MARK: - Section Header
    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(Theme.Typography.profileSectionHeader)
            .foregroundColor(Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.sm)
    }
}

#Preview {
    SettingsView()
}
