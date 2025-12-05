//
//  AuthViewModel.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/3/25.
//

import Foundation
import Supabase
import GoogleSignIn

@MainActor
@Observable
class AuthViewModel {
    var currentUser: User?
    var isAuthenticated = false
    var isLoading = false
    var errorMessage: String?

    init() {
        // Start monitoring auth state changes
        Task {
            await observeAuthStateChanges()
        }
    }

    // MARK: - Auth State Monitoring

    private func observeAuthStateChanges() async {
        for await state in supabase.auth.authStateChanges {
            if [AuthChangeEvent.initialSession, .signedIn, .signedOut].contains(state.event) {
                // Check if session is expired for initial session
                if state.event == .initialSession, let session = state.session {
                    // Only authenticate if session is not expired
                    if !session.isExpired {
                        currentUser = session.user
                        isAuthenticated = true
                    } else {
                        currentUser = nil
                        isAuthenticated = false
                    }
                } else {
                    // For signedIn and signedOut events, handle normally
                    currentUser = state.session?.user
                    isAuthenticated = state.session != nil
                }
            }
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            currentUser = session.user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
            print("Sign in error: \(error)")
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let session = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            currentUser = session.user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
            print("Sign up error: \(error)")
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await supabase.auth.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
            print("Sign out error: \(error)")
        }
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await supabase.auth.resetPasswordForEmail(email)
        } catch {
            errorMessage = error.localizedDescription
            print("Password reset error: \(error)")
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle(presentingViewController: UIViewController) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Perform Google Sign-In to get credentials
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)

            // Extract the ID token from Google Sign-In result
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Failed to get ID token from Google Sign-In"
                print("Google Sign-In error: No ID token found")
                return
            }

            // Get the access token
            let accessToken = result.user.accessToken.tokenString

            // Sign in to Supabase with the Google credentials
            let session = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )

            currentUser = session.user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
            print("Google Sign-In error: \(error)")
        }
    }
}
