//
//  SettingsView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 1/16/26.
//

import SwiftUI

struct SettingsView: View {
    @State private var userProfile: UserProfile?
    @State private var isLoadingProfile = true
    @State private var usageViewModel = UsageViewModel()
    @State private var showCancelConfirmation = false
    @State private var isCanceling = false
    @State private var showCancelSuccess = false
    @State private var showCancelError = false
    @State private var cancelErrorMessage = ""
    @State private var subscriptionEndDate: Date?

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
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .forceUIKitNavigationBarHidden()
            .alert("Cancel Subscription", isPresented: $showCancelConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Confirm", role: .destructive) {
                    Task { await cancelSubscription() }
                }
            } message: {
                Text("Are you sure you want to cancel your subscription? You will lose access to premium features at the end of your billing period.")
            }
            .task { await loadData() }
        }
    }

    // MARK: - Profile Loading
    private func loadData() async {
        await loadProfile()
        await usageViewModel.fetchUsage()
    }

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
            sectionHeader(title: "SETTINGS")

            VStack(spacing: Theme.Spacing.md) {
                if isLoadingProfile {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xl)
                } else {
                    HStack {
                        Text(planDisplayName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Theme.Colors.textProfilePrimary)

                        Spacer()

                        if let status = userProfile?.subscriptionStatus, isPaidPlan {
                            Text(statusDisplayName(for: status))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(statusColor(for: status))
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(statusColor(for: status).opacity(0.12))
                                .cornerRadius(Theme.CornerRadius.medium)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)

                    if !planHighlights.isEmpty {
                        Divider()
                            .padding(.horizontal, Theme.Spacing.lg)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(planHighlights, id: \.self) { highlight in
                                    Text(highlight)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Theme.Colors.textProfilePrimary)
                                        .padding(.horizontal, Theme.Spacing.md)
                                        .padding(.vertical, Theme.Spacing.sm)
                                        .background(Theme.Colors.backgroundProfile)
                                        .cornerRadius(Theme.CornerRadius.medium)
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
                        }
                        .padding(.bottom, Theme.Spacing.md)
                    }

                    if isPaidPlan, usageViewModel.currentUsage != nil {
                        Divider()
                            .padding(.horizontal, Theme.Spacing.lg)

                        usageSummaryRow
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.bottom, Theme.Spacing.md)
                    } else if usageViewModel.isLoading, isPaidPlan {
                        Divider()
                            .padding(.horizontal, Theme.Spacing.lg)

                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
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
            // Only show cancel button for active paid subscriptions (not already canceled)
            if isPaidPlan && userProfile?.subscriptionStatus != .canceled {
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
            Text("Your subscription has been canceled. You will continue to have access until \(formattedEndDate).")
        }
        .alert("Error", isPresented: $showCancelError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cancelErrorMessage)
        }
    }

    private var usageSummaryRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.gold)

            Text(usageSummaryText)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.Colors.textProfilePrimary)

            Spacer()

            if usageViewModel.daysUntilReset > 0 {
                Text("\(usageViewModel.daysUntilReset)d")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }

    private func statusColor(for status: SubscriptionStatus) -> Color {
        switch status {
        case .active:
            return .green
        case .canceled:
            return .orange
        case .pastDue:
            return .red
        default:
            return Theme.Colors.textSecondary
        }
    }

    private func statusDisplayName(for status: SubscriptionStatus) -> String {
        switch status {
        case .active:
            return "Active"
        case .canceled:
            return "Canceled"
        case .pastDue:
            return "Past Due"
        case .trialing:
            return "Trial"
        case .incomplete:
            return "Incomplete"
        case .incompleteExpired:
            return "Expired"
        case .unpaid:
            return "Unpaid"
        }
    }

    // MARK: - Computed Properties
    private var planDisplayName: String {
        userProfile?.billingPlan.displayName ?? "Free"
    }

    private var isPaidPlan: Bool {
        guard let plan = userProfile?.billingPlan else { return false }
        return plan == .silver || plan == .gold || plan == .annual
    }

    private var currentLimits: TierQuotaLimits? {
        if let usage = usageViewModel.currentUsage {
            return TierQuotaLimits(
                messagesLimit: usage.messagesLimit,
                imagesLimit: usage.imagesLimit,
                creditsLimit: usage.creditsLimit
            )
        }

        guard let plan = userProfile?.billingPlan else { return nil }
        switch plan {
        case .free:
            return nil
        case .silver:
            return TierQuotaLimits.limits(for: .silver)
        case .gold:
            return TierQuotaLimits.limits(for: .gold)
        case .annual:
            return TierQuotaLimits.limits(for: .annual)
        }
    }

    private var planHighlights: [String] {
        guard let limits = currentLimits else { return [] }
        return [
            "\(limits.messagesLimit) Messages",
            "\(limits.imagesLimit) Images",
            "\(limits.creditsLimit) Credits"
        ]
    }

    private var usageSummaryText: String {
        guard let usage = usageViewModel.currentUsage else { return "" }
        return "\(usage.creditsRemaining) Credits Remaining"
    }

    // MARK: - Cancel Subscription
    private func cancelSubscription() async {
        isCanceling = true
        defer { isCanceling = false }

        let result = await subscriptionViewModel.cancelSubscription()

        if result.success {
            subscriptionEndDate = result.periodEndDate
            // Reload profile to reflect the updated status
            await loadData()
            showCancelSuccess = true
        } else {
            cancelErrorMessage = subscriptionViewModel.errorMessage ?? "Failed to cancel subscription. Please try again."
            showCancelError = true
        }
    }

    private var formattedEndDate: String {
        guard let date = subscriptionEndDate else {
            return "the end of your billing period"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
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
