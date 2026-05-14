//
//  Theme.swift
//  Renaissance Mobile
//
//  Source of truth: rena-app-redesign.html (Home Screen Redesign spec)
//  Secondary reference: rena-journal-ai-insights.html (AI insight card tints)
//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Token          Value           Role                        │
//  │  ──────────     ──────────────  ────────────────────────    │
//  │  primary        #8E4C5C         Buttons · active nav · tags │
//  │  gradient       #6B3346→#B76E79 Hero / feature cards        │
//  │  accent         #C4929A         Selected state · links      │
//  │  card-blush     #F2D7DB         Journal / reflection cards  │
//  │  card-white     #FFFFFF         Neutral cards · nav bar     │
//  │  page-bg        #FFF8F6         Screen background only      │
//  │  text-hi        #3D2B2E         Headlines · strong text     │
//  │  text-lo        #B8A9AB         Subtitles · inactive        │
//  └─────────────────────────────────────────────────────────────┘

import SwiftUI

// MARK: - App Theme

struct Theme {

    // MARK: - Brand Palette

    struct Brand {
        // ── Core ────────────────────────────────────────────────────
        /// #8E4C5C — primary CTA, active nav, icon accents, tags
        static let mauveBerry   = Color(hex: "#8E4C5C")
        /// #C4929A — calendar selection, links, highlights (Dusty Rose)
        static let dustyRose    = Color(hex: "#C4929A")
        /// #B76E79 — gradient light end, concern / flag indicator (Rose Gold)
        static let roseGold     = Color(hex: "#B76E79")
        /// #6B3346 — gradient dark end
        static let gradDark     = Color(hex: "#6B3346")

        // ── Text ────────────────────────────────────────────────────
        /// #3D2B2E — headlines, display text, center FAB
        static let charcoalRose = Color(hex: "#3D2B2E")
        /// #B8A9AB — subtitles, inactive icons, metadata
        static let warmGray     = Color(hex: "#B8A9AB")

        // ── Backgrounds ─────────────────────────────────────────────
        /// #FFF8F6 — screen / page background only
        static let pageBg       = Color(hex: "#FFF8F6")
        /// #FFFFFF — neutral cards, calendar, nav bar
        static let cardWhite    = Color.white
        /// #F2D7DB — journal / reflection card fills
        static let softBlush    = Color(hex: "#F2D7DB")
        /// #FAF0F0 — alternate section background
        static let palePink     = Color(hex: "#FAF0F0")

        // ── Functional tints ────────────────────────────────────────
        /// rgba(142,76,92,0.10) — icon wells, badges, arrow buttons
        static let primaryDim   = Color(hex: "#8E4C5C").opacity(0.10)
        /// rgba(196,146,154,0.14) — hover/selection fills
        static let accentDim    = Color(hex: "#C4929A").opacity(0.14)
        /// rgba(196,146,154,0.18) — universal card border
        static let border       = Color(hex: "#C4929A").opacity(0.18)

        // ── AI insight card tints (rena-journal-ai-insights.html) ───
        /// #FEF0F2 — Rose Gold concern card background
        static let concernTint  = Color(hex: "#FEF0F2")
        /// #FDF5F6 — Dusty Rose reminder card background
        static let reminderTint = Color(hex: "#FDF5F6")
        /// #F8EDF0 — Mauve Berry progress card background
        static let positiveTint = Color(hex: "#F8EDF0")

        // ── Legacy (kept for backward compatibility) ─────────────────
        /// Deprecated — use `pageBg` for backgrounds, `mauveBerry` for actions
        static let cream        = Color(hex: "#FFF8F6")
        /// Deprecated legacy accent — not in redesign spec
        static let gold         = Color(hex: "#D0BB95")
        /// Deprecated — use `pageBg`
        static let palePinkAlt  = Color.white
    }

    // MARK: - Semantic Colors

    struct Colors {
        // ── Actions ─────────────────────────────────────────────────
        static let primary          = Brand.mauveBerry    // CTA buttons
        static let primaryDim       = Brand.primaryDim    // Icon wells, badge backgrounds
        static let accent           = Brand.dustyRose     // Selection, links, "View all"
        static let accentDim        = Brand.accentDim     // Subtle fills

        // ── Backgrounds ─────────────────────────────────────────────
        static let pageBg           = Brand.pageBg        // Screen background
        static let cardWhite        = Brand.cardWhite     // Neutral cards
        static let cardBlush        = Brand.softBlush     // Journal / blush cards
        static let inputBackground  = Brand.cardWhite

        // ── Text ────────────────────────────────────────────────────
        static let textPrimary      = Brand.charcoalRose
        static let textSecondary    = Brand.warmGray
        static let textMuted        = Brand.warmGray

        // ── Border ──────────────────────────────────────────────────
        static let border           = Brand.border

        // ── Status ──────────────────────────────────────────────────
        static let online           = Color(hex: "#10B981")
        static let warning          = Color(hex: "#F59E0B")
        static let error            = Color(hex: "#EF4444")

        // ── Backward-compatible aliases ──────────────────────────────
        static let backgroundLight          = Brand.cardWhite
        static let backgroundChat           = Brand.cardWhite
        static let backgroundHome           = Brand.pageBg          // was #F0E8E5
        static let backgroundProcedures     = Brand.cardWhite
        static let backgroundProfile        = Brand.cardWhite
        static let backgroundWelcome        = Brand.pageBg
        static let cardBackground           = Brand.cardWhite
        static let iconCircleBackground     = Brand.softBlush
        static let categoryCircleBackground = Brand.softBlush
        static let accentProcedures         = Brand.softBlush
        static let roseGold                 = Brand.roseGold
        static let gold                     = Brand.gold

        static let textChatPrimary          = Brand.charcoalRose
        static let textChatSecondary        = Brand.warmGray
        static let textHomePrimary          = Brand.charcoalRose
        static let textHomeMuted            = Brand.warmGray
        static let textProceduresPrimary    = Brand.charcoalRose
        static let textProceduresSubtle     = Brand.warmGray
        static let textProfilePrimary       = Brand.charcoalRose
        static let textWelcomePrimary       = Brand.charcoalRose
        static let textWelcomeSecondary     = Brand.warmGray
        static let textTertiary             = Color(hex: "#9CA3AF")

        static let borderLight              = Brand.border
        static let borderBlush              = Brand.softBlush
        static let conciergeBubble          = Brand.softBlush

        // Per-screen primary action aliases
        static let primaryChat              = Brand.mauveBerry
        static let primaryHome              = Brand.mauveBerry
        static let primaryProcedures        = Brand.mauveBerry
        static let primaryProfile           = Brand.softBlush
        static let primaryWelcome           = Brand.dustyRose
    }

    // MARK: - Gradients

    struct Gradients {
        /// Hero / feature card — 130deg, #6B3346 → #8E4C5C (52%) → #B76E79
        /// Used: explore card, recovery hero, AI logo mark background
        static let hero = LinearGradient(
            stops: [
                .init(color: Brand.gradDark,   location: 0.00),
                .init(color: Brand.mauveBerry, location: 0.52),
                .init(color: Brand.roseGold,   location: 1.00)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Blush card — 145deg, #F8E9EF → #F0D2DA
        /// Used: journal main card, reflection card fills
        static let blushCard = LinearGradient(
            colors: [Color(hex: "#F8E9EF"), Color(hex: "#F0D2DA")],
            startPoint: UnitPoint(x: 0.15, y: 0),
            endPoint: UnitPoint(x: 0.85, y: 1)
        )

        /// Accent — Dusty Rose → Mauve Berry (kept for backward compat)
        static let accent = LinearGradient(
            colors: [Brand.dustyRose, Brand.mauveBerry],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Dark header (kept for backward compat)
        static let dark = LinearGradient(
            colors: [Brand.charcoalRose, Color(hex: "#2A1E20")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Insights card tint (kept for backward compat)
        static let insightsCard = LinearGradient(
            colors: [Color.white, Brand.dustyRose.opacity(0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Outfit Font Helpers
    // Bundled via Fonts/Outfit-*.ttf + UIAppFonts in Info.plist.

    struct Outfit {
        static func light(_ size: CGFloat)    -> Font { .custom("Outfit-Light",    size: size) }
        static func regular(_ size: CGFloat)  -> Font { .custom("Outfit-Regular",  size: size) }
        static func medium(_ size: CGFloat)   -> Font { .custom("Outfit-Medium",   size: size) }
        static func semiBold(_ size: CGFloat) -> Font { .custom("Outfit-SemiBold", size: size) }
        static func bold(_ size: CGFloat)     -> Font { .custom("Outfit-Bold",     size: size) }
    }

    // MARK: - Manrope Font Helpers
    // Bundled via Fonts/Manrope-*.otf + UIAppFonts in Info.plist.
    // Used for display headings in onboarding and key UI moments.

    struct Manrope {
        static func bold(_ size: CGFloat)      -> Font { .custom("Manrope-Bold",      size: size) }
        static func extraBold(_ size: CGFloat) -> Font { .custom("Manrope-ExtraBold", size: size) }
    }

    // MARK: - Plus Jakarta Sans Font Helpers
    // Bundled via Fonts/PlusJakartaSans-*.ttf + UIAppFonts in Info.plist.
    // Used for body, labels, and supporting text throughout onboarding.

    struct PlusJakartaSans {
        static func regular(_ size: CGFloat)  -> Font { .custom("PlusJakartaSans-Regular",  size: size) }
        static func medium(_ size: CGFloat)   -> Font { .custom("PlusJakartaSans-Medium",   size: size) }
        static func semiBold(_ size: CGFloat) -> Font { .custom("PlusJakartaSans-SemiBold", size: size) }
    }

    // MARK: - Typography
    // Headers: Cormorant Garamond via .design(.serif)
    // Body/UI: Outfit via Theme.Outfit helpers

    struct Typography {
        // ── Display — Cormorant Garamond ────────────────────────────
        /// 36px light serif — greeting display ("Hello, Patty")
        static let displayGreeting  = Font.system(size: 36, weight: .light,   design: .serif)
        /// 30px regular serif — screen-level header ("My Journal")
        static let displayScreen    = Font.system(size: 30, weight: .regular, design: .serif)
        /// 26px medium serif — hero card title ("Explore Procedures")
        static let displayHero      = Font.system(size: 26, weight: .medium,  design: .serif)
        /// 40px light serif — large numeric display (recovery day number)
        static let displayNumeric   = Font.system(size: 40, weight: .light,   design: .serif)

        // ── UI — Outfit ──────────────────────────────────────────────
        /// 15px semibold — section headers
        static let sectionHeader    = Outfit.semiBold(15)
        /// 14px semibold — CTA button labels
        static let buttonLabel      = Outfit.semiBold(14)
        /// 13px semibold — card titles, tags, nav items (active)
        static let cardTitle        = Outfit.semiBold(13)
        /// 13px regular — body text, ask-sub
        static let body             = Outfit.regular(13)
        /// 12px regular — compact body
        static let bodySmall        = Outfit.regular(12)
        /// 11px regular — links ("View all", "See all")
        static let link             = Outfit.regular(11)
        /// 9px regular — eyebrows, day names, metadata
        static let eyebrow          = Outfit.regular(9)
        /// 12px light — subtitles, descriptions
        static let subtext          = Outfit.light(12)
        /// 11px light — small descriptions, inactive states
        static let subtextSmall     = Outfit.light(11)

        // ── Backward-compatible aliases ──────────────────────────────
        static let welcomeHeader        = Font.system(size: 28, weight: .semibold)
        static let welcomeTitle         = Font.system(size: 32, weight: .bold)
        static let welcomeSubtitle      = Font.system(size: 15, weight: .light)
        static let homeHeader           = Font.system(size: 32, weight: .light, design: .serif)
        static let chatHeader           = Font.system(size: 18, weight: .light, design: .serif)
        static let sectionTitle         = Font.system(size: 18, weight: .regular)
        static let profileName          = Font.system(size: 24, weight: .bold)
        static let profileSectionHeader = Font.system(size: 12, weight: .bold)
        static let cardSubtitle         = Font.system(size: 15, weight: .light)
        static let heroTitle            = Font.system(size: 24, weight: .light, design: .serif)
        static let heroSubtitle         = Font.system(size: 15, weight: .light)
        static let categoryLabel        = Font.system(size: 14, weight: .regular)
        static let cardLabel            = Font.system(size: 14, weight: .semibold)
        static let serifPrompt          = Font.system(size: 13, weight: .light, design: .serif)
        static let messageText          = Font.system(size: 16)
        static let timestamp            = Font.system(size: 13, weight: .medium)
        static let statusText           = Font.system(size: 14, weight: .medium)
        static let dateDivider          = Font.system(size: 12, weight: .semibold)
        static let inputText            = Font.system(size: 16)
        static let caption              = Font.system(size: 11, weight: .medium)
        static let label                = Font.system(size: 13, weight: .medium)
    }

    // MARK: - Spacing (8-pt grid)

    struct Spacing {
        static let xs: CGFloat   = 4
        static let sm: CGFloat   = 8
        static let md: CGFloat   = 12
        static let lg: CGFloat   = 16
        static let xl: CGFloat   = 24
        static let xxl: CGFloat  = 40
        static let xxxl: CGFloat = 60
    }

    // MARK: - Corner Radius

    struct CornerRadius {
        static let small:   CGFloat = 8
        static let medium:  CGFloat = 12
        static let large:   CGFloat = 16    // standard card
        static let xlarge:  CGFloat = 20    // hero / recovery card
        static let xxlarge: CGFloat = 22    // explore card
        static let pill:    CGFloat = 100   // capsule buttons (CSS: border-radius 100px)
        static let full:    CGFloat = 9999
    }

    // MARK: - Shadows
    // CSS values → SwiftUI: radius ≈ blur / 2

    struct Shadow {
        /// shadow-s: 0 2px 14px rgba(142,76,92,0.07) — cards, calendar, nav
        static let card      = (color: Color(hex: "#8E4C5C").opacity(0.07), radius: CGFloat(7),  x: CGFloat(0), y: CGFloat(2))
        /// shadow-m: 0 5px 24px rgba(142,76,92,0.12) — elevated cards, journal main
        static let elevated  = (color: Color(hex: "#8E4C5C").opacity(0.12), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(5))
        /// shadow-l: 0 10px 48px rgba(107,51,70,0.22) — deep elevation
        static let large     = (color: Color(hex: "#6B3346").opacity(0.22), radius: CGFloat(24), x: CGFloat(0), y: CGFloat(10))
        /// hero: 0 8px 32px rgba(107,51,70,0.34) — explore / hero gradient card
        static let hero      = (color: Color(hex: "#6B3346").opacity(0.34), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
        /// button: 0 4px 14px rgba(142,76,92,0.28) — primary CTA button
        static let button    = (color: Color(hex: "#8E4C5C").opacity(0.28), radius: CGFloat(7),  x: CGFloat(0), y: CGFloat(4))
        /// calActive: 0 3px 12px rgba(196,146,154,0.42) — calendar selected day pill
        static let calActive = (color: Color(hex: "#C4929A").opacity(0.42), radius: CGFloat(6),  x: CGFloat(0), y: CGFloat(3))
        /// nav: 0 4px 32px rgba(61,43,46,0.13) — bottom nav bar
        static let nav       = (color: Color(hex: "#3D2B2E").opacity(0.13), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(4))

        // Backward-compatible alias
        static let glow      = (color: Color(hex: "#8E4C5C").opacity(0.15), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(6))
    }

    // MARK: - Icon Sizes

    struct IconSize {
        static let small:        CGFloat = 18
        static let medium:       CGFloat = 22    // standard UI icons
        static let large:        CGFloat = 36
        static let avatar:       CGFloat = 44    // profile avatar in header
        static let iconBox:      CGFloat = 40    // "Ask Rena" icon well
        static let iconArrow:    CGFloat = 30    // small circular arrow button
        static let profileAvatar: CGFloat = 112
        static let iconCircle:   CGFloat = 64

        // Backward-compatible
        static let iconSmall: CGFloat = 18
    }
}
