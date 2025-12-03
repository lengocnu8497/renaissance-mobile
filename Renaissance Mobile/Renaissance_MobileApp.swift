//
//  Renaissance_MobileApp.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

@main
struct Renaissance_MobileApp: App {
    @State private var isLoggedIn = false

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                ContentView()
            } else {
                WelcomeView(
                    onStartConsultation: {
                        isLoggedIn = true
                    },
                    onSignIn: {
                        isLoggedIn = true
                    }
                )
            }
        }
    }
}
