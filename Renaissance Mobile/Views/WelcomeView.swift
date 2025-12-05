//
//  WelcomeView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI

struct WelcomeView: View {
    @State private var showSignIn = false
    @State private var showSignUp = false

    var onStartConsultation: (() -> Void)?
    var onSignIn: (() -> Void)?

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.backgroundWelcome
                .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                Spacer()

                // Main Content - centered
                mainContent
                    .padding(.horizontal, 32)

                Spacer()

                // Footer with buttons
                footerSection
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showSignIn) {
            SignInView(onSignIn: {
                showSignIn = false
                onSignIn?()
            })
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView(
                onSignUp: {
                    showSignUp = false
                    onSignIn?()
                },
                onSignIn: {
                    showSignUp = false
                    showSignIn = true
                }
            )
        }
    }

    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 24) {
            Text("Your Personal Beauty\nConcierge")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(Theme.Colors.textWelcomePrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("Expert guidance for cosmetic procedures,\nright at your fingertips.")
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.textWelcomeSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 16) {
            // Start Consultation Button
            Button(action: {
                onStartConsultation?()
            }) {
                Text("Start My Consultation")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.Colors.textWelcomePrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.Colors.primaryWelcome)
                    .cornerRadius(Theme.CornerRadius.medium)
            }

            // Create Account Button
            Button(action: {
                showSignUp = true
            }) {
                Text("Create Account")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(Theme.CornerRadius.medium)
            }

            // Sign In Link
            Button(action: {
                showSignIn = true
            }) {
                Text("Sign In")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textWelcomeSecondary)
                    .underline()
            }
            .padding(.top, 4)
        }
    }
}

#Preview {
    WelcomeView()
}
