//
//  Theme.swift
//  Renaissance Mobile
//
//  Aligned with Rena Aesthetic Lab brand identity.
//  Source of truth: renaissance-ai-launch/BRANDING.md
//
//  Brand palette:
//    Charcoal Rose  #3D2B2E  — primary text, dark backgrounds
//    Mauve Berry    #8E4C5C  — secondary accent, primary action
//    Dusty Rose     #C4929A  — brand accent, buttons, labels
//    Rose Gold      #B76E79  — hover states, gradient mid-stops
//    Soft Blush     #F2D7DB  — card fills, icon backgrounds
//    Cream          #FFFFFF  — page background
//    Warm Gray      #B8A9AB  — body copy, muted text
//    Pale Pink      #FFFFFF  — alternate section background
//
//  Typography:
//    Serif   → Cormorant Garamond (.design(.serif) — loaded via Info.plist or system fallback)
//    Sans    → Outfit (.custom("Outfit-*") — loaded via Info.plist or system sans fallback)

import SwiftUI

// MARK: - App Theme
struct Theme {

    // MARK: - Brand Palette (canonical)
    struct Brand {
        static let charcoalRose = Color(hex: "#3D2B2E")
        static let mauveBerry   = Color(hex: "#8E4C5C")
        static let dustyRose    = Color(hex: "#C4929A")
        static let roseGold     = Color(hex: "#B76E79")
        static let softBlush    = Color(hex: "#F2D7DB")
        static let cream        = Color.white
        static let warmGray     = Color(hex: "#B8A9AB")
        static let palePink     = Color.white
        static let gold         = Color(hex: "#D0BB95")   // legacy accent
    }

    // MARK: - Colors
    struct Colors {
        // Primary actions — all on-brand rose/mauve
        static let primary            = Brand.gold
        static let primaryChat        = Brand.dustyRose
        static let primaryHome        = Brand.mauveBerry
        static let primaryProcedures  = Brand.mauveBerry   // was off-brand #2badee
        static let primaryProfile     = Brand.softBlush
        static let primaryWelcome     = Brand.dustyRose

        // Gradients / accents
        static let roseGold           = Brand.roseGold
        static let gold               = Brand.gold

        // Backgrounds
        static let backgroundLight       = Color.white
        static let backgroundChat        = Color.white
        static let backgroundHome        = Color(hex: "#F0E8E5")   // dusty blush — home screen bg
        static let backgroundProcedures  = Color.white
        static let backgroundProfile     = Color.white
        static let backgroundWelcome     = Brand.cream
        static let cardBackground        = Color.white
        static let iconCircleBackground  = Brand.softBlush
        static let categoryCircleBackground = Brand.softBlush
        static let accentProcedures      = Brand.softBlush
        static let inputBackground       = Color.white

        // Text
        static let textPrimary            = Brand.charcoalRose
        static let textSecondary          = Brand.warmGray
        static let textTertiary           = Color(hex: "#9CA3AF")
        static let textChatPrimary        = Brand.charcoalRose
        static let textChatSecondary      = Brand.warmGray
        static let textHomePrimary        = Brand.charcoalRose
        static let textHomeMuted          = Brand.warmGray
        static let textProceduresPrimary  = Brand.charcoalRose
        static let textProceduresSubtle   = Brand.warmGray    // was off-brand #617c89
        static let textProfilePrimary     = Brand.charcoalRose
        static let textWelcomePrimary     = Brand.charcoalRose
        static let textWelcomeSecondary   = Brand.warmGray

        // Borders
        static let borderLight  = Color(hex: "#F1F1F1")
        static let borderBlush  = Brand.softBlush

        // Chat Bubbles
        static let conciergeBubble = Brand.softBlush

        // Status
        static let online   = Color(hex: "#10b981")
        static let warning  = Color(hex: "#F59E0B")
        static let error    = Color(hex: "#EF4444")
    }

    // MARK: - Outfit Font Helpers
    // Bundled via Fonts/Outfit-*.ttf + UIAppFonts in Info.plist.
    // Use these instead of .custom("Outfit-*") inline to keep names DRY.
    struct Outfit {
        static func light(_ size: CGFloat)    -> Font { .custom("Outfit-Light",    size: size) }
        static func regular(_ size: CGFloat)  -> Font { .custom("Outfit-Regular",  size: size) }
        static func semiBold(_ size: CGFloat) -> Font { .custom("Outfit-SemiBold", size: size) }
        static func bold(_ size: CGFloat)     -> Font { .custom("Outfit-Bold",     size: size) }
    }

    // MARK: - Typography
    // Headings: Cormorant Garamond via .design(.serif) (system serif fallback).
    // Body/UI:  Outfit via Theme.Outfit helpers (bundled TTFs).
    struct Typography {
        // Headers
        static let welcomeHeader       = Font.system(size: 28, weight: .semibold)
        static let welcomeTitle        = Font.system(size: 32, weight: .bold)
        static let welcomeSubtitle     = Font.system(size: 15, weight: .light)
        static let homeHeader          = Font.system(size: 32, weight: .light, design: .serif)
        static let chatHeader          = Font.system(size: 18, weight: .light, design: .serif)
        static let sectionTitle        = Font.system(size: 18, weight: .regular)
        static let profileName         = Font.system(size: 24, weight: .bold)
        static let profileSectionHeader = Font.system(size: 12, weight: .bold)

        // Card Text
        static let cardTitle    = Font.system(size: 18, weight: .regular)
        static let cardSubtitle = Font.system(size: 15, weight: .light)   // same as heroSubtitle — canonical subtext style
        static let heroTitle    = Font.system(size: 24, weight: .light, design: .serif)
        static let heroSubtitle = Font.system(size: 15, weight: .light)   // alias of cardSubtitle
        static let categoryLabel = Font.system(size: 14, weight: .regular)
        static let cardLabel    = Font.system(size: 14, weight: .semibold) // inline card titles, CTA labels (e.g. "Ask Rena", "Log")
        static let serifPrompt  = Font.system(size: 13, weight: .light, design: .serif) // soft serif cues, placeholder/muted prompts

        // Chat
        static let messageText = Font.system(size: 16)
        static let timestamp   = Font.system(size: 13, weight: .medium)
        static let statusText  = Font.system(size: 14, weight: .medium)

        // Utility
        static let dateDivider = Font.system(size: 12, weight: .semibold)
        static let inputText   = Font.system(size: 16)
        static let caption     = Font.system(size: 11, weight: .medium)
        static let label       = Font.system(size: 13, weight: .medium)
    }

    // MARK: - Spacing (8-pt grid)
    struct Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 16
        static let xl: CGFloat  = 24
        static let xxl: CGFloat = 40
        static let xxxl: CGFloat = 60
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat  = 8
        static let medium: CGFloat = 12
        static let large: CGFloat  = 16
        static let xlarge: CGFloat = 24
        static let pill: CGFloat   = 50   // brand buttons are pill-shaped
        static let full: CGFloat   = 9999
    }

    // MARK: - Icon Sizes
    struct IconSize {
        static let small: CGFloat        = 18
        static let medium: CGFloat       = 24
        static let large: CGFloat        = 36
        static let avatar: CGFloat       = 40
        static let profileAvatar: CGFloat = 112
        static let iconCircle: CGFloat   = 64
    }

    // MARK: - Shadow
    struct Shadow {
        static let card     = (color: Color.black.opacity(0.04), radius: CGFloat(4),  x: CGFloat(0), y: CGFloat(1))
        static let elevated = (color: Color.black.opacity(0.08), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(4))
        static let glow     = (color: Brand.mauveBerry.opacity(0.15), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(6))
    }

    // MARK: - Gradients
    struct Gradients {
        /// Hero: cream → soft blush → pale pink (matches landing page hero)
        static let hero = LinearGradient(
            colors: [Brand.cream, Brand.softBlush, Brand.palePink],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        /// Brand accent: dusty rose → mauve berry
        static let accent = LinearGradient(
            colors: [Brand.dustyRose, Brand.mauveBerry],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        /// Dark header: charcoal rose → deeper charcoal
        static let dark = LinearGradient(
            colors: [Brand.charcoalRose, Color(hex: "#2A1E20")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        /// Insights card: white → dusty rose tint (home screen recovery/journal cards)
        static let insightsCard = LinearGradient(
            colors: [Color.white, Brand.dustyRose.opacity(0.18)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}
