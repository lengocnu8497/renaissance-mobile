//
//  ProfileView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var showPasswordSecurity = false
    @State private var showHelpSupport = false
    @State private var usageViewModel = UsageViewModel()

    // Profile data
    @State private var userProfile: UserProfile?
    @State private var isLoadingProfile = true

    // Service
    private let profileService = UserProfileService(supabase: supabase)
    var onBackButtonTapped: (() -> Void)? = nil

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    profileNavigationBar
                    profileHeader
                    accountSection
                    usageSection
                    supportSection
                    logOutButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showPasswordSecurity) {
            PasswordSecurityView()
        }
        .sheet(isPresented: $showHelpSupport) {
            HelpSupportView()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .forceUIKitNavigationBarHidden()
        .task {
            await loadData()
        }
        .onChange(of: showEditProfile) { _, isShowing in
            // Reload profile when returning from EditProfileView
            if !isShowing {
                Task {
                    await loadData()
                }
            }
        }
    }

    // MARK: - Custom Navigation Bar
    private var profileNavigationBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                onBackButtonTapped?()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ProfilePalette.primary)
                    .frame(width: 46, height: 46)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.92))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.72), lineWidth: 1)
                    )
                    .shadow(color: ProfilePalette.primaryInk.opacity(0.08), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.plain)

            VStack(spacing: 4) {
                Text("Account")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(ProfilePalette.muted)

                Text("Profile & Settings")
                    .font(Theme.Outfit.bold(24))
                    .foregroundStyle(ProfilePalette.text)
            }
            .frame(maxWidth: .infinity)

            Circle()
                .fill(Color.clear)
                .frame(width: 46, height: 46)
        }
        .padding(.horizontal, 2)
        .padding(.top, 4)
    }

    // MARK: - Profile Loading

    private func loadData() async {
        await loadProfile()
        await usageViewModel.fetchUsage()
    }

    /// Load user profile from database
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
            // Continue with nil profile - will show default avatar
        }
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ProfilePalette.rose.opacity(0.22), .clear],
                            center: .center,
                            startRadius: 12,
                            endRadius: 82
                        )
                    )
                    .frame(width: 164, height: 164)

                Group {
                    if isLoadingProfile {
                        ProgressView()
                            .scaleEffect(1.4)
                            .frame(width: 128, height: 128)
                    } else if let imageUrl = userProfile?.profileImageUrl, let url = URL(string: imageUrl) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 128, height: 128)
                                .clipShape(Circle())
                        } placeholder: {
                            ProgressView()
                                .frame(width: 128, height: 128)
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#D6DDD0"), Color(hex: "#C2CCB7")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            Image(systemName: "person.fill")
                                .font(.system(size: 52, weight: .regular))
                                .foregroundStyle(ProfilePalette.primaryInk.opacity(0.62))
                        }
                        .frame(width: 128, height: 128)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .shadow(color: ProfilePalette.primaryInk.opacity(0.10), radius: 24, x: 0, y: 12)
            }
            .padding(.top, 8)

            VStack(spacing: 12) {
                Text(userProfile?.fullName ?? "User")
                    .font(Theme.Outfit.bold(38))
                    .foregroundStyle(ProfilePalette.primaryInk)

                if let planBadge = planBadgeText {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(ProfilePalette.primary)
                            .frame(width: 9, height: 9)

                        Text(planBadge)
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(1.4)
                            .textCase(.uppercase)
                            .foregroundStyle(ProfilePalette.primaryInk)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(ProfilePalette.primarySoft)
                    .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    // MARK: - Usage
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if isPaidPlan {
                sectionHeader(title: "USAGE")

                if usageViewModel.isLoading && usageViewModel.currentUsage == nil {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 16)
                } else if let usage = usageViewModel.currentUsage {
                    usageCard(usage)
                }
            }
        }
    }

    private func usageCard(_ usage: UsageQuota) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Usage")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2.4)
                        .foregroundStyle(Color.white.opacity(0.72))

                    Text("AI credits at \(usagePercentage)%")
                        .font(Theme.Outfit.bold(24))
                        .foregroundStyle(Color.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Remaining")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(Color.white.opacity(0.62))

                    Text("\(usage.creditsRemaining) credits")
                        .font(Theme.Outfit.semiBold(18))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            VStack(spacing: 10) {
                HStack {
                    Text("Monthly allocation")
                    Spacer()
                    Text("\(usage.creditsUsed) / \(usage.creditsLimit) used")
                }
                .font(Theme.Outfit.medium(12))
                .foregroundStyle(Color.white.opacity(0.74))

                GeometryReader { proxy in
                    let width = proxy.size.width
                    let progress = max(0, min(CGFloat(usagePercentage) / 100, 1))

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.14))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [ProfilePalette.primarySoft, ProfilePalette.roseSoft],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(12, width * progress))
                    }
                }
                .frame(height: 12)
            }
            .padding(.top, 18)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [ProfilePalette.primaryInk, ProfilePalette.primary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: ProfilePalette.primaryInk.opacity(0.16), radius: 20, x: 0, y: 12)
    }

    // MARK: - Account Section
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "ACCOUNT")

            VStack(spacing: 12) {
                profileActionRow(
                    title: "Personal Information",
                    icon: "person",
                    iconBackground: ProfilePalette.primarySoft,
                    iconColor: ProfilePalette.primary
                ) {
                    showEditProfile = true
                }

                profileActionRow(
                    title: "Settings",
                    icon: "gearshape",
                    iconBackground: Color.white,
                    iconColor: ProfilePalette.roseDeep
                ) {
                    showSettings = true
                }

                profileActionRow(
                    title: "Password & Security",
                    icon: "lock",
                    iconBackground: Color.white,
                    iconColor: ProfilePalette.primary
                ) {
                    showPasswordSecurity = true
                }
            }
        }
    }

    // MARK: - Support Section
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "SUPPORT")

            VStack(spacing: 12) {
                profileActionRow(
                    title: "Help Center",
                    icon: "questionmark.circle",
                    iconBackground: ProfilePalette.roseSoft,
                    iconColor: ProfilePalette.roseDeep
                ) {
                    showHelpSupport = true
                }

                profileActionRow(
                    title: "Terms of Service",
                    icon: "doc.text",
                    iconBackground: Color.white,
                    iconColor: ProfilePalette.primary
                ) {
                    UIApplication.shared.open(AppConfig.termsOfUseURL)
                }
            }
        }
    }

    // MARK: - Log Out Button
    private var logOutButton: some View {
        Button(action: {
            Task {
                await authViewModel.signOut()
            }
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                if authViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .red))
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 20))
                    Text("Log Out")
                        .font(Theme.Outfit.semiBold(16))
                }
            }
            .foregroundStyle(ProfilePalette.alert)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(ProfilePalette.alert.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
            )
        }
        .disabled(authViewModel.isLoading)
        .padding(.top, 4)
    }

    // MARK: - Section Header
    private func sectionHeader(title: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(ProfilePalette.muted)

            Rectangle()
                .fill(ProfilePalette.line)
                .frame(height: 1)
        }
    }

    private func profileActionRow(
        title: String,
        icon: String,
        iconBackground: Color,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(iconBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.55), lineWidth: 1)
                        )

                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 52, height: 52)

                Text(title)
                    .font(Theme.Outfit.semiBold(16))
                    .foregroundStyle(ProfilePalette.text)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ProfilePalette.muted.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.90))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.72), lineWidth: 1)
                    )
            )
            .shadow(color: ProfilePalette.primaryInk.opacity(0.06), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
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

    private var planBadgeText: String? {
        guard let plan = userProfile?.billingPlan else { return nil }
        if plan == .free {
            return "Free plan"
        }

        if let status = userProfile?.subscriptionStatus {
            return "\(plan.displayName) plan \(statusDisplayName(for: status))"
        }

        return "\(plan.displayName) plan"
    }

    private var isPaidPlan: Bool {
        guard let plan = userProfile?.billingPlan else { return false }
        return plan == .weekly || plan == .monthly || plan == .yearly
    }

    private var usagePercentage: Int {
        guard let usage = usageViewModel.currentUsage, usage.creditsLimit > 0 else { return 0 }
        return Int((Double(usage.creditsUsed) / Double(usage.creditsLimit)) * 100.0)
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [ProfilePalette.backgroundTop, ProfilePalette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(ProfilePalette.primarySoft.opacity(0.75))
                .frame(width: 260, height: 260)
                .blur(radius: 28)
                .offset(x: -120, y: -340)

            Circle()
                .fill(ProfilePalette.roseSoft.opacity(0.95))
                .frame(width: 220, height: 220)
                .blur(radius: 34)
                .offset(x: 150, y: -280)
        }
        .ignoresSafeArea()
    }
}

private enum ProfilePalette {
    static let shell = Color(hex: "#EEF1E8")
    static let backgroundTop = Color(hex: "#F4F6EF")
    static let backgroundBottom = Color(hex: "#EDF1E8")
    static let line = Color(hex: "#CFD6C7")
    static let text = Color(hex: "#1F261D")
    static let muted = Color(hex: "#687064")
    static let primary = Color(hex: "#516048")
    static let primaryInk = Color(hex: "#314030")
    static let primarySoft = Color(hex: "#D9E3CE")
    static let rose = Color(hex: "#B07B7A")
    static let roseSoft = Color(hex: "#F1DDDA")
    static let roseDeep = Color(hex: "#976769")
    static let alert = Color(hex: "#9B4D50")
}

#Preview {
    ProfileView()
}
