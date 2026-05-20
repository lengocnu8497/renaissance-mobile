//
//  SettingsView.swift
//  Renaissance Mobile
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionStore.self) private var subscriptionStore

    @State private var userProfile: UserProfile?
    @State private var isLoadingProfile    = true
    @State private var usageViewModel      = UsageViewModel()
    @State private var showCancelConfirmation = false
    @State private var isCanceling         = false
    @State private var showCancelSuccess   = false
    @State private var showCancelError     = false
    @State private var cancelErrorMessage  = ""
    @State private var subscriptionEndDate: Date?
    @State private var showUpgradePaywall = false
    @State private var showRetentionOffer = false

    private let profileService        = UserProfileService(supabase: supabase)
    private let subscriptionViewModel = SubscriptionViewModel()

    // Design tokens
    private enum S {
        static let bg      = Color(hex: "#F8F8FF")
        static let ink     = Color(hex: "#2D2575")
        static let muted   = Color(hex: "#7B6FC0")
        static let primary = Color(hex: "#6C63FF")
        static let soft    = Color(hex: "#EAE7FF")
        static let line    = Color(hex: "#D4CCFF")
        static let success = Color(hex: "#5BBF84")
        static let alert   = Color(hex: "#E05252")

        static func heading(_ size: CGFloat) -> Font { .custom("Manrope", size: size).weight(.bold) }
        static func semi(_ size: CGFloat)   -> Font { .custom("PlusJakartaSans-SemiBold", size: size) }
        static func reg(_ size: CGFloat)    -> Font { .custom("PlusJakartaSans-Regular", size: size) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(S.line)
                .frame(width: 36, height: 4)
                .padding(.top, 14)

            // Header
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(S.muted)
                        .frame(width: 32, height: 32)
                        .background(S.soft)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Subscription")
                    .font(S.heading(18))
                    .foregroundColor(S.ink)

                Spacer()

                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    subscriptionSection
                    reviewSection
                    cancelSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(S.bg.ignoresSafeArea())
        .alert("Cancel Subscription", isPresented: $showCancelConfirmation) {
            Button("Back", role: .cancel) {}
            Button("Confirm", role: .destructive) {
                Task { await cancelSubscription() }
            }
        } message: {
            Text(
                isAppStoreManagedSubscription
                    ? "We'll open Apple's subscription management so you can update or cancel your plan there."
                    : "Are you sure? You'll keep access until the end of your billing period."
            )
        }
        .alert(isAppStoreManagedSubscription ? "Manage Subscription" : "Subscription Canceled", isPresented: $showCancelSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                isAppStoreManagedSubscription
                    ? "Your App Store subscription settings are now open."
                    : "Your subscription has been canceled. You'll keep access until \(formattedEndDate)."
            )
        }
        .alert("Error", isPresented: $showCancelError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cancelErrorMessage)
        }
        .sheet(isPresented: $showRetentionOffer) {
            DiscountOfferView(
                onSubscribed: {
                    showRetentionOffer = false
                    Task { await loadData(refreshSubscriptionStore: true, showLoadingState: false) }
                },
                onSkip: {
                    showRetentionOffer = false
                    showCancelConfirmation = true
                }
            )
        }
        .sheet(isPresented: $showUpgradePaywall) {
            SubscriptionPaywallView(
                onDismiss: { showUpgradePaywall = false },
                onSubscribed: {
                    showUpgradePaywall = false
                    Task { await loadData(refreshSubscriptionStore: true, showLoadingState: false) }
                }
            )
        }
        .task { await loadData(refreshSubscriptionStore: true, showLoadingState: true) }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
            Task { await loadData(refreshSubscriptionStore: false, showLoadingState: false) }
        }
    }

    // MARK: - Subscription section

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("SUBSCRIPTION")

            VStack(spacing: 0) {
                if isLoadingProfile {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.vertical, 28)
                } else {
                    // Plan row
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(planDisplayName)
                                .font(S.heading(20))
                                .foregroundColor(S.ink)
                            Text(isPaidPlan ? "Premium access active" : "Upgrade to unlock all features")
                                .font(S.reg(13))
                                .foregroundColor(S.muted)
                        }

                        Spacer()

                        if let status = resolvedSubscriptionStatus, isPaidPlan {
                            statusBadge(status)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)

                    if isPaidPlan {
                        Divider()
                            .background(S.line.opacity(0.5))
                            .padding(.horizontal, 18)

                        premiumPlanDetails
                    } else {
                        Divider()
                            .background(S.line.opacity(0.5))
                            .padding(.horizontal, 18)

                        Text("Chat AI, photo tracking, and your full personalized roadmap unlock with a subscription.")
                            .font(S.reg(13))
                            .foregroundColor(S.muted)
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                            .padding(.bottom, 10)

                        Button {
                            showUpgradePaywall = true
                        } label: {
                            Text("Upgrade to Premium")
                                .font(S.semi(15))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(S.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 16)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(S.line.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: S.primary.opacity(0.06), radius: 10, x: 0, y: 3)
        }
    }

    @ViewBuilder
    private var premiumPlanDetails: some View {
        if !planHighlights.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(planHighlights, id: \.self) { tag in
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(S.primary)
                            Text(tag)
                                .font(S.semi(12))
                                .foregroundColor(S.ink)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(S.soft)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 18)
            }
            .padding(.vertical, 12)
        }

        if let usage = usageViewModel.currentUsage {
            Divider()
                .background(S.line.opacity(0.5))
                .padding(.horizontal, 18)

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(S.primary)
                    Text(usageSummaryText)
                        .font(S.semi(14))
                        .foregroundColor(S.ink)
                }
                Spacer()
                if usageViewModel.daysUntilReset > 0 {
                    Text("Resets in \(usageViewModel.daysUntilReset)d")
                        .font(S.reg(12))
                        .foregroundColor(S.muted)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            // Usage bar
            GeometryReader { proxy in
                let used   = Double(usage.creditsUsed)
                let limit  = Double(max(usage.creditsLimit, 1))
                let pct    = max(0, min(used / limit, 1))
                ZStack(alignment: .leading) {
                    Capsule().fill(S.soft)
                    Capsule()
                        .fill(LinearGradient(colors: [S.primary, S.ink.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, proxy.size.width * pct))
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 18)
            .padding(.bottom, 16)

        } else if usageViewModel.isLoading {
            HStack { Spacer(); ProgressView(); Spacer() }
                .padding(.vertical, 14)
        }
    }

    // MARK: - Review section

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("FEEDBACK")

            Button {
                Task { @MainActor in _ = await ReviewRequestHelper.requestWhenReady() }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(S.soft)
                            .frame(width: 44, height: 44)
                        Image(systemName: "star.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(hex: "#F5C842"))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Rate Rena")
                            .font(S.semi(15))
                            .foregroundColor(S.ink)
                        Text("Leave a quick App Store rating")
                            .font(S.reg(12))
                            .foregroundColor(S.muted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(S.muted.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(S.line.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: S.primary.opacity(0.06), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Cancel section

    @ViewBuilder
    private var cancelSection: some View {
        if isPaidPlan {
            Button {
                showRetentionOffer = true
            } label: {
                Group {
                    if isCanceling {
                        ProgressView().tint(S.alert)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 16, weight: .semibold))
                            Text(isAppStoreManagedSubscription ? "Manage in App Store" : "Cancel Subscription")
                                .font(S.semi(15))
                        }
                        .foregroundColor(S.alert)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(S.alert.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(S.alert.opacity(0.20), lineWidth: 1)
                )
            }
            .disabled(isCanceling || resolvedSubscriptionStatus == .canceled)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Shared components

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(S.semi(11))
            .tracking(2.2)
            .foregroundColor(S.muted)
    }

    private func statusBadge(_ status: SubscriptionStatus) -> some View {
        let color: Color = {
            switch status {
            case .active:   return S.success
            case .canceled: return Color.orange
            case .pastDue:  return S.alert
            default:        return S.muted
            }
        }()
        return Text(statusDisplayName(for: status))
            .font(S.semi(11))
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Data loading

    private func loadData(refreshSubscriptionStore: Bool, showLoadingState: Bool) async {
        if refreshSubscriptionStore { await subscriptionStore.prepare() }
        await loadProfile(showLoadingState: showLoadingState)
        if isPaidPlan { await usageViewModel.fetchUsage() } else { usageViewModel.clearUsage() }
    }

    private func loadProfile(showLoadingState: Bool) async {
        if showLoadingState || userProfile == nil { isLoadingProfile = true }
        defer { isLoadingProfile = false }
        do {
            let profile = try await profileService.getUserProfile()
            await MainActor.run { userProfile = profile }
        } catch {
            print("Failed to load profile: \(error.localizedDescription)")
        }
    }

    private func cancelSubscription() async {
        isCanceling = true
        defer { isCanceling = false }
        let result = await subscriptionViewModel.cancelSubscription(isAppStoreManaged: isAppStoreManagedSubscription)
        if result.success {
            subscriptionEndDate = result.periodEndDate
            if !isAppStoreManagedSubscription {
                await loadData(refreshSubscriptionStore: false, showLoadingState: false)
            }
            showCancelSuccess = true
        } else {
            cancelErrorMessage = subscriptionViewModel.errorMessage ?? "Failed to cancel. Please try again."
            showCancelError = true
        }
    }

    // MARK: - Computed

    private var planDisplayName: String { resolvedSubscriptionState.planDisplayName }
    private var isPaidPlan: Bool        { resolvedSubscriptionState.hasPremiumAccess }
    private var resolvedSubscriptionStatus: SubscriptionStatus? { resolvedSubscriptionState.status }
    private var isAppStoreManagedSubscription: Bool { resolvedSubscriptionState.isAppStoreManaged }

    private var resolvedSubscriptionState: SubscriptionAccessEvaluator.ResolvedSubscriptionState {
        SubscriptionAccessEvaluator.resolvedState(
            userProfile,
            localTier: subscriptionStore.activeTier,
            localStatus: subscriptionStore.subscriptionStatus,
            localHasActiveSubscription: subscriptionStore.hasActiveSubscription
        )
    }

    private var currentLimits: TierQuotaLimits? {
        if let usage = usageViewModel.currentUsage {
            return TierQuotaLimits(messagesLimit: usage.messagesLimit, imagesLimit: usage.imagesLimit, creditsLimit: usage.creditsLimit)
        }
        guard let tier = resolvedSubscriptionState.tier, isPaidPlan else { return nil }
        return TierQuotaLimits.limits(for: tier)
    }

    private var planHighlights: [String] {
        guard let limits = currentLimits else { return [] }
        return ["\(limits.creditsLimit) AI Credits / month"]
    }

    private var usageSummaryText: String {
        guard let usage = usageViewModel.currentUsage else { return "" }
        return "\(usage.creditsRemaining) credits left"
    }

    private var formattedEndDate: String {
        guard let date = subscriptionEndDate else { return "the end of your billing period" }
        let f = DateFormatter(); f.dateStyle = .long; f.timeStyle = .none
        return f.string(from: date)
    }

    private func statusDisplayName(for status: SubscriptionStatus) -> String {
        switch status {
        case .active:            return "Active"
        case .canceled:          return "Canceled"
        case .pastDue:           return "Past Due"
        case .trialing:          return "Trial"
        case .incomplete:        return "Incomplete"
        case .incompleteExpired: return "Expired"
        case .unpaid:            return "Unpaid"
        }
    }
}

#Preview { SettingsView() }
