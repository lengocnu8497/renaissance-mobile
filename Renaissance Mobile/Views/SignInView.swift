//
//  SignInView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false

    var onSignIn: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Welcome back text
                    Text("Welcome back")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(Theme.Colors.textWelcomePrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
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
                    .padding(.bottom, 16)

                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if isPasswordVisible {
                                TextField("Password", text: $password)
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.textWelcomePrimary)
                            } else {
                                SecureField("Password", text: $password)
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.textWelcomePrimary)
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

                    // Forgot password
                    Button(action: {
                        // Handle forgot password
                    }) {
                        Text("Forgot your password?")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#6366f1"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                    // Sign in button
                    Button(action: {
                        onSignIn?()
                    }) {
                        Text("Sign in")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.black)
                            .cornerRadius(12)
                    }
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
                        onSignIn?()
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
                        onSignIn?()
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

                    // Create account link
                    HStack(spacing: 4) {
                        Text("First time here?")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)

                        Button(action: {
                            // Navigate to create account
                        }) {
                            Text("Create an account")
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
                    Text("Sign in")
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
    SignInView()
}
