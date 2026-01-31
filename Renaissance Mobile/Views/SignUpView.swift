//
//  SignUpView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/4/25.
//

import SwiftUI
import UIKit

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false

    var onSignUp: (() -> Void)?
    var onSignIn: (() -> Void)?

    private var isFormValid: Bool {
        !fullName.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        password == confirmPassword
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Let's get started text
                    Text("Let's get started")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(Theme.Colors.textWelcomePrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        .padding(.bottom, 32)

                    // Full Name field
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("", text: $fullName, prompt: Text("Full Name").foregroundColor(Color.gray.opacity(0.7)))
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(12)
                            .autocapitalization(.words)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("", text: $email, prompt: Text("Email").foregroundColor(Color.gray.opacity(0.7)))
                            .font(.system(size: 16))
                            .foregroundColor(.black)
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
                    .padding(.bottom, 16)

                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if isPasswordVisible {
                                TextField("", text: $password, prompt: Text("Password").foregroundColor(Color.gray.opacity(0.7)))
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                            } else {
                                SecureField("", text: $password, prompt: Text("Password").foregroundColor(Color.gray.opacity(0.7)))
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                            }

                            Button(action: {
                                isPasswordVisible.toggle()
                            }) {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#2badee"))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // Confirm Password field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if isConfirmPasswordVisible {
                                TextField("", text: $confirmPassword, prompt: Text("Confirm Password").foregroundColor(Color.gray.opacity(0.7)))
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                            } else {
                                SecureField("", text: $confirmPassword, prompt: Text("Confirm Password").foregroundColor(Color.gray.opacity(0.7)))
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                            }

                            Button(action: {
                                isConfirmPasswordVisible.toggle()
                            }) {
                                Image(systemName: isConfirmPasswordVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#2badee"))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    !confirmPassword.isEmpty && password != confirmPassword
                                    ? Color.red.opacity(0.5)
                                    : Color.gray.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)

                    // Password mismatch error
                    if !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Passwords do not match")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                            .padding(.bottom, 16)
                    } else {
                        // Spacer to maintain layout
                        Color.clear.frame(height: 24)
                    }

                    // Error message from auth
                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Create Account button
                    Button(action: {
                        Task {
                            await authViewModel.signUp(email: email, password: password)
                            if authViewModel.isAuthenticated {
                                onSignUp?()
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
                            Text("Create Account")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(isFormValid ? Color.black : Color.gray.opacity(0.5))
                                .cornerRadius(12)
                        }
                    }
                    .disabled(authViewModel.isLoading || !isFormValid)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                    // Divider with "or"
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.3))

                        Text("or")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, 12)

                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.3))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                    // Continue with Google
                    Button(action: {
                        Task {
                            guard let viewController = getRootViewController() else {
                                authViewModel.errorMessage = "Unable to present Google Sign-In"
                                return
                            }
                            await authViewModel.signInWithGoogle(presentingViewController: viewController)
                            if authViewModel.isAuthenticated {
                                onSignUp?()
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.system(size: 20))
                                .foregroundColor(Theme.Colors.textWelcomePrimary)

                            Text("Continue With Google")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Theme.Colors.textWelcomePrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // Continue with Apple
                    Button(action: {
                        Task {
                            await authViewModel.signInWithApple()
                            if authViewModel.isAuthenticated {
                                onSignUp?()
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20))
                                .foregroundColor(Theme.Colors.textWelcomePrimary)

                            Text("Continue With Apple")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Theme.Colors.textWelcomePrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)

                    // Sign in link
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)

                        Button(action: {
                            onSignIn?()
                        }) {
                            Text("Sign in")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#6366f1"))
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .background(Theme.Colors.backgroundWelcome)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Create account")
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

    // Helper function to get the root view controller for presenting Google Sign-In
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return nil
        }

        // Get the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        return topController
    }
}

#Preview {
    SignUpView()
        .environment(AuthViewModel())
}
