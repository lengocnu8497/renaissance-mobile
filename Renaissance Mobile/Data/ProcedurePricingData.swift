//
//  ProcedurePricingData.swift
//  Renaissance Mobile
//
//  Price ranges are national averages derived from ASPS 2023 Statistics Report,
//  RealSelf Cost Guides, and industry surveys. Prices are in USD and represent
//  provider fees only — facility, anesthesia, and follow-up costs may be additional.
//  See disclaimer in CostEstimatorView.
//

import Foundation

// MARK: - Models

struct ProcedurePricing: Identifiable {
    let id: String               // matches ProcedureChecklist id
    let displayName: String
    let category: String
    let lowPrice: Int            // USD
    let avgPrice: Int
    let highPrice: Int
    let unit: PricingUnit
    let typicalSessions: Int     // how many sessions/units for typical result
    let priceNote: String        // e.g. "per syringe", "per treatment area"
}

enum PricingUnit: String {
    case perSession   = "per session"
    case perSyringe   = "per syringe"
    case perUnit      = "per unit"
    case perArea      = "per area"
    case perVial      = "per vial"
    case perPulse     = "per treatment"
}

// MARK: - Region Modifier

enum PricingRegion: String, CaseIterable {
    case nationalAverage  = "National Average"
    case majorCity        = "Major City (NYC, LA, SF, Miami)"
    case midsize          = "Mid-size City"
    case rural            = "Rural / Suburban"

    var multiplier: Double {
        switch self {
        case .nationalAverage: return 1.0
        case .majorCity:       return 1.35
        case .midsize:         return 1.0
        case .rural:           return 0.80
        }
    }

    /// Infer region from the first 3 digits of a US zip code.
    static func infer(fromZip zip: String) -> PricingRegion {
        guard zip.count >= 3 else { return .nationalAverage }
        let prefix = String(zip.prefix(3))
        guard let code = Int(prefix) else { return .nationalAverage }

        // Major metro zip prefix ranges (approximate)
        let majorCityRanges: [ClosedRange<Int>] = [
            // NYC area
            100...102, 103...104, 110...119,
            // LA area
            900...902, 903...908,
            // SF Bay Area
            940...944,
            // Miami
            330...331, 334...334,
            // Chicago
            606...606, 607...607,
            // Boston
            021...022,
            // DC
            200...205,
            // Seattle
            980...981,
            // Austin / Dallas
            787...787, 750...752
        ]

        // Rural heuristic: very low-density zip prefixes
        let ruralRanges: [ClosedRange<Int>] = [
            590...599, // Montana
            580...589, // North/South Dakota
            496...499, // Upper Michigan
            693...693, // Nebraska panhandle
            820...831  // Wyoming
        ]

        for range in majorCityRanges where range.contains(code) {
            return .majorCity
        }
        for range in ruralRanges where range.contains(code) {
            return .rural
        }
        return .midsize
    }
}

// MARK: - Registry

struct ProcedurePricingData {

    static let all: [ProcedurePricing] = [
        // Injectables
        ProcedurePricing(
            id: "botox",
            displayName: "Botox / Neurotoxin",
            category: "Injectables",
            lowPrice: 200, avgPrice: 450, highPrice: 900,
            unit: .perArea,
            typicalSessions: 1,
            priceNote: "per treatment area; typical full-face treatment covers 2–3 areas"
        ),
        ProcedurePricing(
            id: "lip_fillers",
            displayName: "Lip Fillers",
            category: "Injectables",
            lowPrice: 500, avgPrice: 700, highPrice: 1200,
            unit: .perSyringe,
            typicalSessions: 1,
            priceNote: "per syringe; most patients need 0.5–1 syringe for natural results"
        ),
        ProcedurePricing(
            id: "dermal_fillers_cheeks",
            displayName: "Cheek / Midface Fillers",
            category: "Injectables",
            lowPrice: 600, avgPrice: 900, highPrice: 1800,
            unit: .perSyringe,
            typicalSessions: 1,
            priceNote: "per syringe; typical cheek augmentation uses 1–2 syringes per side"
        ),
        ProcedurePricing(
            id: "kybella",
            displayName: "Kybella",
            category: "Injectables",
            lowPrice: 600, avgPrice: 1200, highPrice: 1800,
            unit: .perSession,
            typicalSessions: 3,
            priceNote: "per session; most patients need 2–4 sessions for full results"
        ),
        // Skin Treatments
        ProcedurePricing(
            id: "microneedling",
            displayName: "Microneedling",
            category: "Skin",
            lowPrice: 200, avgPrice: 400, highPrice: 700,
            unit: .perSession,
            typicalSessions: 4,
            priceNote: "per session; a series of 3–6 sessions is typically recommended"
        ),
        ProcedurePricing(
            id: "chemical_peel_superficial",
            displayName: "Chemical Peel (Superficial)",
            category: "Skin",
            lowPrice: 100, avgPrice: 175, highPrice: 300,
            unit: .perSession,
            typicalSessions: 4,
            priceNote: "per session; series of 4–6 treatments for optimal results"
        ),
        ProcedurePricing(
            id: "chemical_peel",
            displayName: "Chemical Peel (Medium/Deep)",
            category: "Skin",
            lowPrice: 400, avgPrice: 900, highPrice: 3000,
            unit: .perSession,
            typicalSessions: 1,
            priceNote: "single treatment; medium peels $400–$900, deep phenol peels up to $3,000"
        ),
        ProcedurePricing(
            id: "microdermabrasion",
            displayName: "Microdermabrasion",
            category: "Skin",
            lowPrice: 75, avgPrice: 150, highPrice: 300,
            unit: .perSession,
            typicalSessions: 6,
            priceNote: "per session; a series of 5–10 sessions is typically recommended"
        ),
        ProcedurePricing(
            id: "hydrafacial",
            displayName: "HydraFacial",
            category: "Facials",
            lowPrice: 150, avgPrice: 250, highPrice: 450,
            unit: .perSession,
            typicalSessions: 4,
            priceNote: "per session; monthly maintenance recommended for sustained results"
        ),
        // Laser Treatments
        ProcedurePricing(
            id: "laser_hair_removal",
            displayName: "Laser Hair Removal",
            category: "Body",
            lowPrice: 100, avgPrice: 285, highPrice: 600,
            unit: .perArea,
            typicalSessions: 6,
            priceNote: "per session per area; small areas (lip, chin) ~$100, large areas (full legs, back) ~$500+"
        ),
        ProcedurePricing(
            id: "laser_resurfacing",
            displayName: "Laser Resurfacing (Fraxel / CO2)",
            category: "Non-Surgical",
            lowPrice: 1000, avgPrice: 2200, highPrice: 5000,
            unit: .perSession,
            typicalSessions: 3,
            priceNote: "per session; non-ablative Fraxel ~$1,000–$2,000; ablative CO2 ~$2,000–$5,000"
        ),
        ProcedurePricing(
            id: "ipl_photofacial",
            displayName: "IPL Photofacial",
            category: "Skin",
            lowPrice: 300, avgPrice: 500, highPrice: 900,
            unit: .perSession,
            typicalSessions: 3,
            priceNote: "per session; a series of 3–5 treatments typically recommended"
        ),
        // Non-Surgical Lifting
        ProcedurePricing(
            id: "pdo_thread_lift",
            displayName: "PDO Thread Lift",
            category: "Non-Surgical",
            lowPrice: 1500, avgPrice: 2500, highPrice: 4500,
            unit: .perSession,
            typicalSessions: 1,
            priceNote: "full-face treatment; price depends on number of threads used (20–60 threads typical)"
        ),
        ProcedurePricing(
            id: "ultherapy",
            displayName: "Ultherapy",
            category: "Non-Surgical",
            lowPrice: 1500, avgPrice: 3000, highPrice: 5000,
            unit: .perSession,
            typicalSessions: 1,
            priceNote: "full-face and neck; results build over 3–6 months; maintenance every 1–2 years"
        ),
        ProcedurePricing(
            id: "radiofrequency",
            displayName: "Radiofrequency Skin Tightening",
            category: "Non-Surgical",
            lowPrice: 1000, avgPrice: 2000, highPrice: 4000,
            unit: .perSession,
            typicalSessions: 3,
            priceNote: "per session; devices vary (Thermage, Morpheus8, Sofwave)"
        ),
        // Body Contouring
        ProcedurePricing(
            id: "coolsculpting",
            displayName: "CoolSculpting",
            category: "Body",
            lowPrice: 600, avgPrice: 1500, highPrice: 4000,
            unit: .perArea,
            typicalSessions: 2,
            priceNote: "per treatment area (applicator); most patients treat 2–4 areas per session"
        ),
        ProcedurePricing(
            id: "emsculpt",
            displayName: "Emsculpt / Emsculpt Neo",
            category: "Body",
            lowPrice: 750, avgPrice: 1000, highPrice: 1500,
            unit: .perSession,
            typicalSessions: 4,
            priceNote: "per session per area; protocol is 4 sessions over 2 weeks"
        ),
        // Surgical (estimates only — wide variability)
        ProcedurePricing(
            id: "rhinoplasty",
            displayName: "Rhinoplasty (Nose Job)",
            category: "Surgical",
            lowPrice: 5000, avgPrice: 8000, highPrice: 15000,
            unit: .perSession,
            typicalSessions: 1,
            priceNote: "surgeon fee only; total cost including anesthesia and facility typically adds $2,000–$4,000"
        ),
        ProcedurePricing(
            id: "blepharoplasty",
            displayName: "Eyelid Surgery (Blepharoplasty)",
            category: "Surgical",
            lowPrice: 2000, avgPrice: 4000, highPrice: 8000,
            unit: .perSession,
            typicalSessions: 1,
            priceNote: "surgeon fee; upper or lower eyelids; both upper and lower adds ~50% to cost"
        ),
        ProcedurePricing(
            id: "facelift",
            displayName: "Facelift (Rhytidectomy)",
            category: "Surgical",
            lowPrice: 8000, avgPrice: 14000, highPrice: 30000,
            unit: .perSession,
            typicalSessions: 1,
            priceNote: "surgeon fee only; total with facility and anesthesia typically $12,000–$35,000+"
        )
    ]

    static func pricing(for id: String) -> ProcedurePricing? {
        all.first { $0.id == id }
    }

    static var categories: [String] {
        Array(Set(all.map { $0.category })).sorted()
    }

    static func byCategory(_ category: String) -> [ProcedurePricing] {
        category == "All" ? all : all.filter { $0.category == category }
    }
}
