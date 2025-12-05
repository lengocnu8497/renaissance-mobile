//
//  EnvironmentConfig.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/3/25.
//

import Foundation

enum EnvironmentConfig {
    // MARK: - Supabase Configuration
    // Credentials are stored here for easy environment-specific configuration
    // You can use different values for DEBUG vs RELEASE builds

    static var supabaseURL: String {
        #if DEBUG
        return "https://gqporfhogzyqgsxincbx.supabase.co"
        #else
        return "https://gqporfhogzyqgsxincbx.supabase.co"
        #endif
    }

    static var supabaseAnonKey: String {
        #if DEBUG
        return "sb_publishable_DPHSDnwQi_gXLCN6WSyd0w_u4tfurQ-"
        #else
        return "sb_publishable_DPHSDnwQi_gXLCN6WSyd0w_u4tfurQ-"
        #endif
    }
}
