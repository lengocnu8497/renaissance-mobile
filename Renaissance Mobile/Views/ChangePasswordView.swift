//
//  ChangePasswordView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/20/25.
//

import SwiftUI
import Supabase
import Auth

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showCurrentPassword = false
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false
    @State private var showForgotPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundProfile
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        // Current Password Section
                        currentPasswordSection
                            .padding(.top, Theme.Spacing.lg)

                        // New Password Section
                        newPasswordSection

                        // Confirm Password Section
                        confirmPasswordSection

                        // Error/Success Message
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal, Theme.Spacing.lg)
                        }

                        if let successMessage {
                            Text(successMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                                .padding(.horizontal, Theme.Spacing.lg)
                        }

                        // Save Button
                        saveButton
                            .padding(.top, Theme.Spacing.md)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
            }
            .navigationTitle("Change Password")
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
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }

    // MARK: - Current Password Section
    private var currentPasswordSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("CURRENT PASSWORD")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.xs)

            HStack {
                if showCurrentPassword {
                    TextField("Enter current password", text: $currentPassword)
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.textProfilePrimary)
                } else {
                    SecureField("Enter current password", text: $currentPassword)
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.textProfilePrimary)
                }

                Button(action: {
                    showCurrentPassword.toggle()
                }) {
                    Image(systemName: showCurrentPassword ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(Color.white.opacity(0.5))
            .cornerRadius(Theme.CornerRadius.medium)

            // Forgot Password Link
            HStack {
                Spacer()
                Button(action: {
                    showForgotPassword = true
                }) {
                    Text("Forgot Password?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.textProfilePrimary)
                }
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.top, Theme.Spacing.xs)
        }
    }

    // MARK: - New Password Section
    private var newPasswordSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("NEW PASSWORD")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.xs)

            HStack {
                if showNewPassword {
                    TextField("Enter new password", text: $newPassword)
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.textProfilePrimary)
                } else {
                    SecureField("Enter new password", text: $newPassword)
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.textProfilePrimary)
                }

                Button(action: {
                    showNewPassword.toggle()
                }) {
                    Image(systemName: showNewPassword ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(Color.white.opacity(0.5))
            .cornerRadius(Theme.CornerRadius.medium)

            // Password Requirements
            Text("Must be at least 8 characters with 1 special character.")
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.top, Theme.Spacing.xs)
        }
    }

    // MARK: - Confirm Password Section
    private var confirmPasswordSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("CONFIRM NEW PASSWORD")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.xs)

            HStack {
                if showConfirmPassword {
                    TextField("Re-enter new password", text: $confirmPassword)
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.textProfilePrimary)
                } else {
                    SecureField("Re-enter new password", text: $confirmPassword)
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.textProfilePrimary)
                }

                Button(action: {
                    showConfirmPassword.toggle()
                }) {
                    Image(systemName: showConfirmPassword ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(Color.white.opacity(0.5))
            .cornerRadius(Theme.CornerRadius.medium)
        }
    }

    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: {
            Task {
                await handleSaveChanges()
            }
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Save Changes")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                isFormValid ? Color.black : Color.black.opacity(0.3)
            )
            .cornerRadius(Theme.CornerRadius.large)
        }
        .disabled(!isFormValid || isLoading)
    }

    // MARK: - Validation
    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        isPasswordValid(newPassword)
    }

    private func isPasswordValid(_ password: String) -> Bool {
        // At least 8 characters with 1 special character
        let passwordRegex = "^(?=.*[!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>\\/?]).{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordPredicate.evaluate(with: password)
    }

    // MARK: - Handle Save
    private func handleSaveChanges() async {
        // Clear previous messages
        errorMessage = nil
        successMessage = nil
        isLoading = true
        defer { isLoading = false }

        // Validate passwords match
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords do not match"
            return
        }

        // Validate password requirements
        guard isPasswordValid(newPassword) else {
            errorMessage = "Password must be at least 8 characters with 1 special character"
            return
        }

        do {
            // Call Supabase to update password
            // Note: User must be authenticated to update password
            _ = try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            successMessage = "Password updated successfully"

            // Clear fields
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""

            // Dismiss after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            errorMessage = "Failed to update password: \(error.localizedDescription)"
        }
    }
}

// MARK: - Forgot Password View (Placeholder)
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var successMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundProfile
                    .ignoresSafeArea()

                VStack(spacing: Theme.Spacing.xl) {
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.lg)

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("EMAIL")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, Theme.Spacing.xs)

                        TextField("Enter your email", text: $email)
                            .font(.system(size: 16))
                            .foregroundColor(Theme.Colors.textProfilePrimary)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(Theme.Spacing.lg)
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(Theme.CornerRadius.medium)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, Theme.Spacing.lg)
                    }

                    if let successMessage {
                        Text(successMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                            .padding(.horizontal, Theme.Spacing.lg)
                    }

                    Button(action: {
                        Task {
                            await handleResetPassword()
                        }
                    }) {
                        HStack(spacing: Theme.Spacing.sm) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Send Reset Link")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(email.isEmpty ? Color.black.opacity(0.3) : Color.black)
                        .cornerRadius(Theme.CornerRadius.large)
                    }
                    .disabled(email.isEmpty || isLoading)
                    .padding(.horizontal, Theme.Spacing.lg)

                    Spacer()
                }
            }
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.Colors.textProfilePrimary)
                    }
                }
            }
        }
    }

    private func handleResetPassword() async {
        errorMessage = nil
        successMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase.auth.resetPasswordForEmail(email)
            successMessage = "Reset link sent! Check your email."

            // Dismiss after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        } catch {
            errorMessage = "Failed to send reset link: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ChangePasswordView()
}
