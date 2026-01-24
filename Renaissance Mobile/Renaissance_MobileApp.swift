//
//  Renaissance_MobileApp.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI
import GoogleSignIn
import StripePaymentSheet

@main
struct Renaissance_MobileApp: App {
    @State private var authViewModel = AuthViewModel()

    init() {
        // Configure Google Sign-In with your iOS Client ID
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "636103668184-sflddmlbj90salbiit9ted0m0lhrdmag.apps.googleusercontent.com"
        )

        // Configure Stripe SDK
        STPAPIClient.shared.publishableKey = EnvironmentConfig.stripePublishableKey
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    ContentView()
                        .environment(authViewModel)
                } else {
                    WelcomeView(
                        onStartConsultation: {
                            // Navigate to consultation (can still bypass auth for this flow if needed)
                        },
                        onSignIn: {
                            // Auth handled by AuthViewModel, no need to manually set state
                        }
                    )
                    .environment(authViewModel)
                }
            }
            .sheet(isPresented: Binding(
                get: { authViewModel.showUpdatePassword },
                set: { authViewModel.showUpdatePassword = $0 }
            )) {
                UpdatePasswordView()
                    .environment(authViewModel)
            }
            .onOpenURL { url in
                Task {
                    await authViewModel.handleDeepLink(url)
                }
            }
        }
    }
}
