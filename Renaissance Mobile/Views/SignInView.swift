//
//  SignInView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI
import UIKit

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var showError = false
    @State private var showSignUp = false
    @State private var showResetPassword = false

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
                        TextField("", text: $email, prompt: Text("Email").foregroundColor(.gray.opacity(0.7)))
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
                                TextField("", text: $password, prompt: Text("Password").foregroundColor(.gray.opacity(0.7)))
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.textWelcomePrimary)
                            } else {
                                SecureField("", text: $password, prompt: Text("Password").foregroundColor(.gray.opacity(0.7)))
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.textWelcomePrimary)
                            }

                            Button(action: {
                                isPasswordVisible.toggle()
                            }) {
                                Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
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
                        showResetPassword = true
                    }) {
                        Text("Forgot your password?")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#6366f1"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

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

                    // Sign in button
                    Button(action: {
                        Task {
                            await authViewModel.signIn(email: email, password: password)
                            if authViewModel.isAuthenticated {
                                onSignIn?()
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
                            Text("Sign in")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.black)
                                .cornerRadius(12)
                        }
                    }
                    .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
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
                                onSignIn?()
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            googleColorIcon

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
                                onSignIn?()
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

                    // Create account link
                    HStack(spacing: 4) {
                        Text("First time here?")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)

                        Button(action: {
                            showSignUp = true
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
            .sheet(isPresented: $showSignUp) {
                SignUpView(
                    onSignUp: {
                        showSignUp = false
                        onSignIn?()
                    },
                    onSignIn: {
                        showSignUp = false
                    }
                )
            }
            .sheet(isPresented: $showResetPassword) {
                ResetPasswordView(
                    onSignIn: {
                        showResetPassword = false
                    }
                )
            }
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

    // MARK: - Google Icon
    private var googleColorIcon: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let r = size.width * 0.36
            let lw = size.width * 0.22

            let blue   = Color(red: 0.259, green: 0.522, blue: 0.957)  // #4285F4
            let red    = Color(red: 0.918, green: 0.263, blue: 0.208)  // #EA4335
            let yellow = Color(red: 0.984, green: 0.737, blue: 0.020)  // #FBBC05
            let green  = Color(red: 0.204, green: 0.659, blue: 0.325)  // #34A853

            // Four arc segments (0° = right, increasing = clockwise on screen)
            let segments: [(Color, Double, Double)] = [
                (blue,   -15,  75),   // right side
                (red,     75, 195),   // top + left
                (yellow, 195, 255),   // lower-left
                (green,  255, 345)    // bottom
            ]
            for (color, start, end) in segments {
                var arc = Path()
                arc.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                           startAngle: .degrees(start), endAngle: .degrees(end),
                           clockwise: false)
                context.stroke(arc, with: .color(color),
                               style: StrokeStyle(lineWidth: lw, lineCap: .butt))
            }

            // Blue horizontal bar (right half, at midline)
            let half = lw * 0.3
            var bar = Path()
            bar.addRect(CGRect(x: cx, y: cy - half, width: r + lw * 0.5, height: half * 2))
            context.fill(bar, with: .color(blue))
        }
        .frame(width: 22, height: 22)
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
    SignInView()
}
