//
//  Theme.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

// MARK: - App Theme
struct Theme {
    // MARK: - Colors
    struct Colors {
        // Primary
        static let primary = Color(hex: "#D0BB95")
        static let primaryChat = Color(hex: "#D9BFA9")
        static let primaryHome = Color(hex: "#d1a38a")

        // Backgrounds
        static let backgroundLight = Color(hex: "#f7f7f6")
        static let backgroundChat = Color(hex: "#F8F8F8")
        static let backgroundHome = Color(hex: "#fdf8f5")
        static let cardBackground = Color.white
        static let iconCircleBackground = Color(hex: "#DBEAFE")
        static let categoryCircleBackground = Color(hex: "#f9ebe4")
        static let inputBackground = Color.white

        // Text
        static let textPrimary = Color(hex: "#1F2937")
        static let textSecondary = Color(hex: "#6B7280")
        static let textTertiary = Color(hex: "#9CA3AF")
        static let textChatPrimary = Color(hex: "#333333")
        static let textChatSecondary = Color(hex: "#999999")
        static let textHomePrimary = Color(hex: "#211713")
        static let textHomeMuted = Color(hex: "#6f6967")

        // Chat Bubbles
        static let conciergeBubble = Color(hex: "#EFEFEF")

        // Status
        static let online = Color(hex: "#10b981")
    }

    // MARK: - Typography
    struct Typography {
        // Headers
        static let welcomeHeader = Font.system(size: 28, weight: .semibold)
        static let homeHeader = Font.system(size: 32, weight: .bold)
        static let chatHeader = Font.system(size: 18, weight: .bold)
        static let sectionTitle = Font.system(size: 20, weight: .bold)

        // Card Text
        static let cardTitle = Font.system(size: 18, weight: .semibold)
        static let cardSubtitle = Font.system(size: 14)
        static let heroTitle = Font.system(size: 24, weight: .bold)
        static let heroSubtitle = Font.system(size: 16, weight: .medium)
        static let categoryLabel = Font.system(size: 14, weight: .semibold)

        // Chat
        static let messageText = Font.system(size: 16)
        static let timestamp = Font.system(size: 13, weight: .medium)
        static let statusText = Font.system(size: 14, weight: .medium)

        // Date Divider
        static let dateDivider = Font.system(size: 12, weight: .semibold)

        // Input
        static let inputText = Font.system(size: 16)
    }

    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 40
        static let xxxl: CGFloat = 60
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 24
        static let full: CGFloat = 9999
    }

    // MARK: - Icon Sizes
    struct IconSize {
        static let small: CGFloat = 18
        static let medium: CGFloat = 24
        static let large: CGFloat = 36
        static let avatar: CGFloat = 40
        static let iconCircle: CGFloat = 64
    }

    // MARK: - Shadow
    struct Shadow {
        static let card = (color: Color.black.opacity(0.04), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(1))
    }
}
