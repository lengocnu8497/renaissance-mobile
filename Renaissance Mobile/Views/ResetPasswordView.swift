//
//  ResetPasswordView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 1/24/26.
//

import SwiftUI

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var email = ""
    @State private var isSubmitted = false
    @State private var showSuccessMessage = false

    var onSignIn: (() -> Void)?

    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Forgot password? heading
                        Text("Forgot password?")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(Theme.Colors.textWelcomePrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 32)
                            .padding(.bottom, 12)

                        // Subtitle
                        Text("Enter your email address and we'll send you a link to reset your password.")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)

                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Email", text: $email)
                                .font(.system(size: 16))
                                .foregroundColor(Theme.Colors.textWelcomePrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(12)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                        // Success message
                        if showSuccessMessage {
                            Text("Password reset link sent! Check your email inbox.")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 12)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Error message
                        if let errorMessage = authViewModel.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 12)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Send Reset Link button
                        Button(action: {
                            Task {
                                await authViewModel.resetPassword(email: email)
                                if authViewModel.errorMessage == nil {
                                    showSuccessMessage = true
                                }
                            }
                        }) {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.black)
                                    .cornerRadius(12)
                            } else {
                                Text("Send Reset Link")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(isEmailValid ? Color.black : Color.gray.opacity(0.5))
                                    .cornerRadius(12)
                            }
                        }
                        .disabled(authViewModel.isLoading || !isEmailValid)
                        .padding(.horizontal, 24)
                    }
                }

                Spacer()

                // Remember your password? Sign In
                HStack(spacing: 4) {
                    Text("Remember your password?")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.textSecondary)

                    Button(action: {
                        dismiss()
                        onSignIn?()
                    }) {
                        Text("Sign In")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#6366f1"))
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Theme.Colors.backgroundWelcome)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Reset Password")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Colors.textWelcomePrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.Colors.textWelcomePrimary)
                    }
                }
            }
        }
    }
}

#Preview {
    ResetPasswordView()
        .environment(AuthViewModel())
}
