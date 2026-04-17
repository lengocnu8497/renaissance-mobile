//
//  PasswordSecurityView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI

struct PasswordSecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showChangePassword = false
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountErrorMessage = ""
    @State private var showDeleteAccountError = false
    @State private var showDeleteAccountSuccess = false

    private let accountDeletionService = AccountDeletionService(supabase: supabase)

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundProfile
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        // Security Section
                        securitySection
                            .padding(.top, Theme.Spacing.lg)

                        // Account Actions Section
                        accountActionsSection

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
            }
            .navigationTitle("Password & Security")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .forceUIKitNavigationBarHidden()
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView()
            }
            .confirmationDialog(
                "Delete Account",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and associated data. This action cannot be undone.")
            }
            .alert("Account Deleted", isPresented: $showDeleteAccountSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your account has been permanently deleted.")
            }
            .alert("Delete Account Failed", isPresented: $showDeleteAccountError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteAccountErrorMessage)
            }
        }
    }

    // MARK: - Security Section
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("SECURITY")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.sm)

            Button(action: {
                showChangePassword = true
            }) {
                HStack(spacing: Theme.Spacing.lg) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                            .fill(Theme.Colors.primaryProfile.opacity(0.2))
                            .frame(width: 36, height: 36)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.Colors.primaryProfile)
                    }

                    // Title
                    Text("Change Password")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.Colors.textProfilePrimary)

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
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

    // MARK: - Account Actions Section
    private var accountActionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("ACCOUNT ACTIONS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.sm)

            Button(action: {
                showDeleteConfirmation = true
            }) {
                HStack(spacing: Theme.Spacing.lg) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 36, height: 36)

                        Image(systemName: "trash.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.red)
                    }

                    // Title
                    Text(isDeletingAccount ? "Deleting Account..." : "Delete Account")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
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
            .disabled(isDeletingAccount || authViewModel.isLoading)
        }
    }

    private func deleteAccount() async {
        guard !isDeletingAccount else { return }

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await accountDeletionService.deleteCurrentAccount()
            await authViewModel.handleLocalAccountRemoval()
            showDeleteAccountSuccess = true
        } catch {
            deleteAccountErrorMessage = error.localizedDescription
            showDeleteAccountError = true
        }
    }
}

#Preview {
    PasswordSecurityView()
}
