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
        static let primaryChat = Color(hex: "#C4929A")
        static let primaryHome = Color(hex: "#8E4C5C")
        static let primaryProcedures = Color(hex: "#2badee")
        static let primaryProfile = Color(hex: "#E6C0C0")
        static let primaryWelcome = Color(hex: "#C4929A")
        static let gold = Color(hex: "#D0BB95")

        // Backgrounds
        static let backgroundLight = Color(hex: "#FFF8F6")
        static let backgroundChat = Color(hex: "#FFF8F6")
        static let backgroundHome = Color(hex: "#FFF8F6")
        static let backgroundProcedures = Color(hex: "#f8f8f8")
        static let backgroundProfile = Color(hex: "#F8F9FA")
        static let backgroundWelcome = Color(hex: "#FFF8F6")
        static let cardBackground = Color.white
        static let iconCircleBackground = Color(hex: "#F2D7DB")
        static let categoryCircleBackground = Color(hex: "#F2D7DB")
        static let accentProcedures = Color(hex: "#ead5d1")
        static let inputBackground = Color.white

        // Text
        static let textPrimary = Color(hex: "#3D2B2E")
        static let textSecondary = Color(hex: "#B8A9AB")
        static let textTertiary = Color(hex: "#9CA3AF")
        static let textChatPrimary = Color(hex: "#3D2B2E")
        static let textChatSecondary = Color(hex: "#B8A9AB")
        static let textHomePrimary = Color(hex: "#3D2B2E")
        static let textHomeMuted = Color(hex: "#B8A9AB")
        static let textProceduresPrimary = Color(hex: "#333333")
        static let textProceduresSubtle = Color(hex: "#617c89")
        static let textProfilePrimary = Color(hex: "#343A40")
        static let textWelcomePrimary = Color(hex: "#333333")
        static let textWelcomeSecondary = Color(hex: "#617c89")

        // Borders
        static let borderLight = Color(hex: "#F1F1F1")

        // Chat Bubbles
        static let conciergeBubble = Color(hex: "#F2D7DB")

        // Status
        static let online = Color(hex: "#10b981")
    }

    // MARK: - Typography
    struct Typography {
        // Headers
        static let welcomeHeader = Font.system(size: 28, weight: .semibold)
        static let welcomeTitle = Font.system(size: 32, weight: .bold)
        static let welcomeSubtitle = Font.system(size: 16)
        static let homeHeader = Font.system(size: 32, weight: .light, design: .serif)
        static let chatHeader = Font.system(size: 18, weight: .light, design: .serif)
        static let sectionTitle = Font.system(size: 18, weight: .regular)
        static let profileName = Font.system(size: 24, weight: .bold)
        static let profileSectionHeader = Font.system(size: 12, weight: .bold)

        // Card Text
        static let cardTitle = Font.system(size: 18, weight: .regular)
        static let cardSubtitle = Font.system(size: 14, weight: .light)
        static let heroTitle = Font.system(size: 24, weight: .light, design: .serif)
        static let heroSubtitle = Font.system(size: 15, weight: .light)
        static let categoryLabel = Font.system(size: 14, weight: .regular)

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
        static let profileAvatar: CGFloat = 112
        static let iconCircle: CGFloat = 64
    }

    // MARK: - Shadow
    struct Shadow {
        static let card = (color: Color.black.opacity(0.04), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(1))
    }
}
