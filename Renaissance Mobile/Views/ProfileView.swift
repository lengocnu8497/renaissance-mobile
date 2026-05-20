//
//  ProfileView.swift
//  Renaissance Mobile
//

import SwiftUI

// MARK: - Design tokens
private enum P {
    static let bg      = Color(hex: "#F8F8FF")
    static let ink     = Color(hex: "#2D2575")
    static let muted   = Color(hex: "#7B6FC0")
    static let primary = Color(hex: "#6C63FF")
    static let soft    = Color(hex: "#EAE7FF")
    static let line    = Color(hex: "#D4CCFF")
    static let alert   = Color(hex: "#E05252")

    static func heading(_ size: CGFloat) -> Font { .custom("Manrope", size: size).weight(.bold) }
    static func semi(_ size: CGFloat)   -> Font { .custom("PlusJakartaSans-SemiBold", size: size) }
    static func body(_ size: CGFloat)   -> Font { .custom("PlusJakartaSans-Regular",  size: size) }
}

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @State private var showEditProfile     = false
    @State private var showSettings        = false
    @State private var showPasswordSecurity = false
    @State private var showHelpSupport     = false
    @State private var usageViewModel      = UsageViewModel()
    @State private var userProfile: UserProfile?
    @State private var isLoadingProfile    = true

    private let profileService = UserProfileService(supabase: supabase)
    var onBackButtonTapped: (() -> Void)? = nil

    var body: some View {
        ZStack {
            P.bg.ignoresSafeArea()

            // Subtle ambient glow
            Circle()
                .fill(P.soft.opacity(0.7))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(x: 140, y: -260)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    navBar
                        .padding(.horizontal, 22)
                        .padding(.top, 12)
                        .padding(.bottom, 24)

                    avatarHeader
                        .padding(.bottom, 32)

                    VStack(spacing: 28) {
                        if isPaidPlan { usageSection }
                        accountSection
                        supportSection
                    }
                    .padding(.horizontal, 22)

                    logOutButton
                        .padding(.horizontal, 22)
                        .padding(.top, 28)
                        .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showEditProfile) { EditProfileView() }
        .sheet(isPresented: $showSettings)    { SettingsView() }
        .sheet(isPresented: $showPasswordSecurity) { PasswordSecurityView() }
        .sheet(isPresented: $showHelpSupport) { HelpSupportView() }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .forceUIKitNavigationBarHidden()
        .task { await loadData() }
        .onChange(of: showEditProfile) { _, isShowing in
            if !isShowing { Task { await loadData() } }
        }
    }

    // MARK: - Nav bar
    private var navBar: some View {
        HStack {
            Button { onBackButtonTapped?() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(P.primary)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: P.primary.opacity(0.10), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("ACCOUNT")
                    .font(P.semi(10))
                    .tracking(2.2)
                    .foregroundColor(P.muted)
                Text("Profile & Settings")
                    .font(P.heading(20))
                    .foregroundColor(P.ink)
            }

            Spacer()

            Circle()
                .fill(Color.clear)
                .frame(width: 40, height: 40)
        }
    }

    // MARK: - Avatar header
    private var avatarHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                // Soft radial glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [P.soft, P.bg.opacity(0)],
                            center: .center, startRadius: 10, endRadius: 90
                        )
                    )
                    .frame(width: 200, height: 200)

                avatarImage
                    .frame(width: 108, height: 108)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(color: P.primary.opacity(0.16), radius: 22, x: 0, y: 8)
            }

            VStack(spacing: 10) {
                Text(userProfile?.fullName ?? "User")
                    .font(P.heading(28))
                    .foregroundColor(P.ink)

                if let badge = planBadgeText {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(P.primary)
                            .frame(width: 6, height: 6)
                        Text(badge)
                            .font(P.semi(12))
                            .tracking(0.3)
                            .foregroundColor(P.ink)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [P.soft, Color(hex: "#E0DBFF")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var avatarImage: some View {
        if isLoadingProfile {
            ProgressView().frame(width: 116, height: 116)
        } else if let url = userProfile?.profileImageUrl.flatMap(URL.init) {
            CachedAsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: [P.soft, P.primary.opacity(0.55)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: "person.fill")
                    .font(.system(size: 46))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }

    // MARK: - Usage section
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("USAGE")

            if usageViewModel.isLoading && usageViewModel.currentUsage == nil {
                HStack { Spacer(); ProgressView(); Spacer() }.padding(.vertical, 16)
            } else if let usage = usageViewModel.currentUsage {
                usageCard(usage)
            }
        }
    }

    private func usageCard(_ usage: UsageQuota) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI CREDITS")
                        .font(P.semi(10))
                        .tracking(2.2)
                        .foregroundColor(P.primary)
                    Text("\(usage.creditsRemaining) remaining")
                        .font(P.heading(22))
                        .foregroundColor(P.ink)
                }
                Spacer()
                // Percentage badge
                Text("\(usagePercentage)% used")
                    .font(P.semi(12))
                    .foregroundColor(P.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(P.line.opacity(0.6), lineWidth: 1))
            }

            // Allocation line
            HStack {
                Text("\(usage.creditsUsed) used")
                    .font(P.body(12))
                    .foregroundColor(P.muted)
                Spacer()
                Text("of \(usage.creditsLimit) monthly")
                    .font(P.body(12))
                    .foregroundColor(P.muted)
            }

            // Progress bar
            GeometryReader { proxy in
                let pct = max(0, min(CGFloat(usagePercentage) / 100, 1))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.55))
                    Capsule()
                        .fill(LinearGradient(colors: [P.primary, P.ink.opacity(0.7)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, proxy.size.width * pct))
                }
            }
            .frame(height: 8)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [P.soft, Color(hex: "#E0DBFF")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: P.primary.opacity(0.10), radius: 14, x: 0, y: 5)
    }

    // MARK: - Account section
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("ACCOUNT")
            VStack(spacing: 10) {
                actionRow(icon: "person",         label: "Personal Information", tint: P.primary) { showEditProfile = true }
                actionRow(icon: "gearshape",      label: "Subscription",         tint: P.primary) { showSettings = true }
                actionRow(icon: "lock",            label: "Password & Security",  tint: P.primary) { showPasswordSecurity = true }
            }
        }
    }

    // MARK: - Support section
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("SUPPORT")
            VStack(spacing: 10) {
                actionRow(icon: "questionmark.circle", label: "Help Center",       tint: P.primary) { showHelpSupport = true }
                actionRow(icon: "doc.text",            label: "Terms of Service",  tint: P.primary) { UIApplication.shared.open(AppConfig.termsOfUseURL) }
            }
        }
    }

    // MARK: - Log out
    private var logOutButton: some View {
        Button {
            Task { await authViewModel.signOut() }
        } label: {
            Group {
                if authViewModel.isLoading {
                    ProgressView().tint(P.alert)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Log Out")
                            .font(P.semi(16))
                    }
                    .foregroundColor(P.alert)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(P.alert.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(P.alert.opacity(0.20), lineWidth: 1)
            )
        }
        .disabled(authViewModel.isLoading)
        .buttonStyle(.plain)
    }

    // MARK: - Components

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(P.semi(11))
            .tracking(2.2)
            .foregroundColor(P.muted)
    }

    private func actionRow(
        icon: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(P.soft)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(tint)
                }

                Text(label)
                    .font(P.semi(15))
                    .foregroundColor(P.ink)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(P.muted.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(P.line.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: P.primary.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data loading

    private func loadData() async {
        await subscriptionStore.prepare()
        await loadProfile()
        if isPaidPlan {
            await usageViewModel.fetchUsage()
        } else {
            usageViewModel.clearUsage()
        }
    }

    private func loadProfile() async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        do {
            let profile = try await profileService.getUserProfile()
            await MainActor.run { userProfile = profile }
        } catch {
            print("Failed to load profile: \(error.localizedDescription)")
        }
    }

    // MARK: - Computed

    private var planBadgeText: String? {
        if !isPaidPlan { return "Free plan" }
        if let status = resolvedSubscriptionStatus {
            return "\(resolvedPlanDisplayName) · \(statusDisplayName(for: status))"
        }
        return "\(resolvedPlanDisplayName) plan"
    }

    private var resolvedPlanDisplayName: String  { resolvedSubscriptionState.planDisplayName }
    private var isPaidPlan: Bool                 { resolvedSubscriptionState.hasPremiumAccess }
    private var resolvedSubscriptionStatus: SubscriptionStatus? { resolvedSubscriptionState.status }

    private var resolvedSubscriptionState: SubscriptionAccessEvaluator.ResolvedSubscriptionState {
        SubscriptionAccessEvaluator.resolvedState(
            userProfile,
            localTier: subscriptionStore.activeTier,
            localStatus: subscriptionStore.subscriptionStatus,
            localHasActiveSubscription: subscriptionStore.hasActiveSubscription
        )
    }

    private var usagePercentage: Int {
        guard let usage = usageViewModel.currentUsage, usage.creditsLimit > 0 else { return 0 }
        return Int((Double(usage.creditsUsed) / Double(usage.creditsLimit)) * 100.0)
    }

    private func statusDisplayName(for status: SubscriptionStatus) -> String {
        switch status {
        case .active:           return "Active"
        case .canceled:         return "Canceled"
        case .pastDue:          return "Past Due"
        case .trialing:         return "Trial"
        case .incomplete:       return "Incomplete"
        case .incompleteExpired: return "Expired"
        case .unpaid:           return "Unpaid"
        }
    }
}

#Preview { ProfileView() }
