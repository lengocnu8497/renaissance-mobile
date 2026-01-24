//
//  AuthViewModel.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/3/25.
//

import Foundation
import Supabase
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@MainActor
@Observable
class AuthViewModel {
    var currentUser: User?
    var isAuthenticated = false
    var isLoading = false
    var errorMessage: String?
    var showUpdatePassword = false
    private var currentNonce: String?

    init() {
        // Start monitoring auth state changes
        Task {
            await observeAuthStateChanges()
        }
    }

    // MARK: - Auth State Monitoring

    private func observeAuthStateChanges() async {
        for await state in supabase.auth.authStateChanges {
            print("Auth state changed: \(state.event)")

            switch state.event {
            case .initialSession:
                // Check if session is expired for initial session
                if let session = state.session {
                    if !session.isExpired {
                        currentUser = session.user
                        isAuthenticated = true
                    } else {
                        currentUser = nil
                        isAuthenticated = false
                    }
                }

            case .signedIn:
                currentUser = state.session?.user
                isAuthenticated = state.session != nil

            case .signedOut:
                currentUser = nil
                isAuthenticated = false
                showUpdatePassword = false

            case .passwordRecovery:
                // User clicked password recovery link and is now authenticated
                print("Password recovery event detected")
                currentUser = state.session?.user
                isAuthenticated = true
                showUpdatePassword = true

            default:
                break
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
            try await supabase.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "renaissance://reset-callback")
            )
        } catch {
            errorMessage = error.localizedDescription
            print("Password reset error: \(error)")
        }
    }

    // MARK: - Handle Deep Link

    func handleDeepLink(_ url: URL) async {
        // Check if this is our app's URL scheme
        guard url.scheme == "renaissance" else { return }

        print("Handling deep link: \(url.absoluteString)")

        do {
            // Exchange the code from the URL for a session
            let session = try await supabase.auth.session(from: url)
            print("Session established for user: \(session.user.email ?? "unknown")")

            // Update state
            currentUser = session.user
            isAuthenticated = true

            // Check if this is a password recovery flow
            // The URL will contain type=recovery after Supabase processes it
            if url.absoluteString.contains("type=recovery") ||
               url.host == "reset-callback" {
                showUpdatePassword = true
            }
        } catch {
            // Check if we already have a session (user might have clicked link while logged in)
            if let session = try? await supabase.auth.session {
                currentUser = session.user
                isAuthenticated = true
                // Still show update password screen for recovery flow
                if url.host == "reset-callback" {
                    showUpdatePassword = true
                }
            } else {
                errorMessage = "Failed to process reset link. Please request a new password reset."
                print("Deep link error: \(error)")
            }
        }
    }

    // MARK: - Update Password

    func updatePassword(newPassword: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await supabase.auth.update(user: UserAttributes(password: newPassword))
            showUpdatePassword = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("Update password error: \(error)")
            return false
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

    // MARK: - Apple Sign In

    func signInWithApple() async {
        isLoading = true
        errorMessage = nil

        let nonce = randomNonceString()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        do {
            let credential = try await performAppleSignIn(request: request)
            try await handleAppleCredential(credential, nonce: nonce)
        } catch {
            isLoading = false
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                // User cancelled, don't show error
                return
            }
            errorMessage = error.localizedDescription
            print("Apple Sign-In error: \(error)")
        }
    }

    private func performAppleSignIn(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorizationAppleIDCredential {
        return try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)
            controller.delegate = delegate
            // Store delegate to prevent deallocation
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            controller.performRequests()
        }
    }

    private func handleAppleCredential(_ credential: ASAuthorizationAppleIDCredential, nonce: String) async throws {
        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get identity token"])
        }

        let session = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: identityToken,
                nonce: nonce
            )
        )

        currentUser = session.user
        isAuthenticated = true
        isLoading = false
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Apple Sign In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation.resume(returning: credential)
        } else {
            continuation.resume(throwing: NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid credential type"]))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
}
