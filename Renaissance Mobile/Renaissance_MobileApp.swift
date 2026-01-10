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
    }
}
