//
//  Renaissance_MobileApp.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI
import GoogleSignIn
import Auth
import Supabase
import CoreText

@main
struct Renaissance_MobileApp: App {
    @State private var authViewModel = AuthViewModel()
    @State private var subscriptionStore = SubscriptionStore.shared

    @Environment(\.scenePhase) private var scenePhase

    init() {
        Analytics.setup()
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "636103668184-sflddmlbj90salbiit9ted0m0lhrdmag.apps.googleusercontent.com"
        )
        Self.registerFonts()
    }

    private static func registerFonts() {
        let fonts = [
            "Manrope-Bold", "Manrope-ExtraBold",
            "Outfit-Light", "Outfit-Regular", "Outfit-SemiBold", "Outfit-Bold",
            "PlusJakartaSans-Regular", "PlusJakartaSans-Medium", "PlusJakartaSans-SemiBold"
        ]
        for name in fonts {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf",
                                            subdirectory: "Fonts") ??
                            Bundle.main.url(forResource: name, withExtension: "ttf")
            else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    ContentView()
                        .environment(authViewModel)
                        .environment(subscriptionStore)
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
                    .environment(subscriptionStore)
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
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                Task {
                    await authViewModel.handleDeepLink(url)
                }
            }
            .task {
                await subscriptionStore.prepare()

                // Warm up Supabase's internal swift-dependencies type metadata
                // on the main actor at launch. Without this, the first access
                // from a concurrent thread triggers a CODESIGNING fault on iOS 26
                // beta (type metadata for Dependencies lives in dyld __DATA_DIRTY
                // which iOS 26 restricts from concurrent lazy initialization).
                _ = try? await supabase.auth.session
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Analytics.sessionStart()
                }
            }
        }
    }
}
