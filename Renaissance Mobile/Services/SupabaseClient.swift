//
//  SupabaseClient.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/3/25.
//
//  IMPORTANT: This file requires the main "Supabase" package to be added to your project.
//  Follow these steps:
//  1. In Xcode, go to File > Add Package Dependencies
//  2. The supabase-swift package should already be in your project
//  3. Make sure to select "Supabase" (in addition to Auth, Functions, etc.)
//  4. Or go to your project settings > Renaissance Mobile target > General > Frameworks, Libraries, and Embedded Content
//  5. Click + and add the "Supabase" library
//

import Foundation
import Supabase
import Auth

// MARK: - Supabase Client Configuration
// Credentials are stored in EnvironmentConfig.swift
// You can configure different values for Debug vs Release builds there

let supabase = SupabaseClient(
    supabaseURL: URL(string: EnvironmentConfig.supabaseURL)!,
    supabaseKey: EnvironmentConfig.supabaseAnonKey,
    options: SupabaseClientOptions(
        auth: .init(
            redirectToURL: URL(string: "renaissance://reset-callback"),
            flowType: .pkce,
            autoRefreshToken: true
        )
    )
)

// MARK: - Apple Sign In Helper
// This will help you implement Sign in with Apple once the Supabase client is set up
/*
 Usage example for Apple Sign In:

 1. Import AuthenticationServices
 2. Get the Apple ID credential
 3. Call Supabase auth with the credentials:

 let session = try await supabase.auth.signInWithIdToken(
     credentials: .init(
         provider: .apple,
         idToken: appleIDCredential.identityToken,
         nonce: nonce
     )
 )
 */
