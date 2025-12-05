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
    @State private var showPaymentMethods = false
    @State private var showPasswordSecurity = false
    @State private var showHelpSupport = false

    var onBackButtonTapped: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Theme.Colors.backgroundProfile
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        // Profile Header
                        profileHeader

                        // Account Section
                        accountSection

                        // Support Section
                        supportSection

                        // Log Out Button
                        logOutButton
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Profile & Settings")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.Colors.textProfilePrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        onBackButtonTapped?()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.Colors.textProfilePrimary)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showPaymentMethods) {
                PaymentMethodsView()
            }
            .sheet(isPresented: $showPasswordSecurity) {
                PasswordSecurityView()
            }
            .sheet(isPresented: $showHelpSupport) {
                HelpSupportView()
            }
        }
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Avatar with Edit Button
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Theme.IconSize.profileAvatar, height: Theme.IconSize.profileAvatar)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .clipShape(Circle())

                Button(action: {
                    // Edit photo action
                }) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.primaryProfile)
                            .frame(width: 32, height: 32)
                        Circle()
                            .stroke(Theme.Colors.cardBackground, lineWidth: 2)
                            .frame(width: 32, height: 32)
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.top, Theme.Spacing.lg)

            // Name and Email
            VStack(spacing: Theme.Spacing.xs) {
                Text("Alexandra Chen")
                    .font(Theme.Typography.profileName)
                    .foregroundColor(Theme.Colors.textProfilePrimary)

                Text("alex.chen@email.com")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Account Section
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "ACCOUNT")

            VStack(spacing: 0) {
                SettingsRowView(icon: "person", title: "Personal Information") {
                    showEditProfile = true
                }

                Divider()
                    .padding(.leading, 56)

                SettingsRowView(icon: "creditcard", title: "Payment Methods") {
                    showPaymentMethods = true
                }

                Divider()
                    .padding(.leading, 56)

                SettingsRowView(icon: "lock", title: "Password & Security") {
                    showPasswordSecurity = true
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

    // MARK: - Support Section
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "SUPPORT")

            VStack(spacing: 0) {
                SettingsRowView(icon: "questionmark.circle", title: "Help Center") {
                    showHelpSupport = true
                }

                Divider()
                    .padding(.leading, 56)

                SettingsRowView(icon: "doc.text", title: "Terms of Service") {
                    // Navigate to terms
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
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.red.opacity(0.1))
            .cornerRadius(Theme.CornerRadius.medium)
        }
        .disabled(authViewModel.isLoading)
        .padding(.top, Theme.Spacing.lg)
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
    ProfileView()
}
