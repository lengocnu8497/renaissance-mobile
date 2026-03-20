//
//  ProcedureReminderConfig.swift
//  Renaissance Mobile
//

import Foundation

// MARK: - Supporting Types

enum ProcedureCategory: String, Codable {
    case injectable       // Botox, fillers, neurotoxins
    case skinTreatment    // Facials, peels, laser, microneedling
    case cosmeticSurgery  // Rhinoplasty, facelift, breast aug, etc.
    case other
}

struct FollowUpMilestone {
    let label: String              // "1-week check-up"
    let daysFromProcedure: Int     // 7, 42, 180, 365
    var enabled: Bool              // user can toggle off individual milestones

    init(label: String, days: Int, enabled: Bool = true) {
        self.label = label
        self.daysFromProcedure = days
        self.enabled = enabled
    }
}

// MARK: - Config

struct ProcedureReminderConfig {
    let category: ProcedureCategory
    let procedureDisplayName: String
    let contextNote: String

    // For injectables & skin treatments — single retreatment reminder
    let retreatmentDays: Int?
    let retreatmentRangeLabel: String?

    // For cosmetic surgery — series of follow-up appointments
    let followUpMilestones: [FollowUpMilestone]

    var isSurgical: Bool { category == .cosmeticSurgery }

    /// Default retreatment date pre-populated in the date picker
    func defaultReminderDate(from procedureDate: Date) -> Date {
        let days = retreatmentDays ?? 180
        return Calendar.current.date(byAdding: .day, value: days, to: procedureDate) ?? procedureDate
    }
}

// MARK: - Lookup

extension ProcedureReminderConfig {

    /// Returns the best-matching config for a free-text procedure name.
    static func config(for procedureName: String) -> ProcedureReminderConfig {
        let n = procedureName.lowercased()

        // ──────────────────────────────────────────────────────────
        // INJECTABLES — Neuromodulators
        // ──────────────────────────────────────────────────────────
        if has(n, ["botox", "dysport", "xeomin", "jeuveau", "daxxify",
                   "neurotoxin", "neuromodulator", "toxin injection"]) {
            return .init(
                category: .injectable,
                procedureDisplayName: "Botox",
                contextNote: "Botox typically lasts 3–4 months. Regular touch-ups maintain your results.",
                retreatmentDays: 90,
                retreatmentRangeLabel: "~3 months",
                followUpMilestones: []
            )
        }

        // ──────────────────────────────────────────────────────────
        // INJECTABLES — Fillers
        // ──────────────────────────────────────────────────────────
        if has(n, ["lip filler", "lip augmentation", "lip injection"]) {
            return .init(
                category: .injectable,
                procedureDisplayName: "Lip Filler",
                contextNote: "Lip filler typically lasts 6–12 months depending on the product used.",
                retreatmentDays: 210,
                retreatmentRangeLabel: "~6–7 months",
                followUpMilestones: []
            )
        }
        if has(n, ["cheek filler", "cheek augmentation", "midface filler", "malar filler"]) {
            return .init(
                category: .injectable,
                procedureDisplayName: "Cheek Filler",
                contextNote: "Cheek filler typically lasts 12–18 months.",
                retreatmentDays: 365,
                retreatmentRangeLabel: "~12 months",
                followUpMilestones: []
            )
        }
        if has(n, ["jawline filler", "jaw filler", "chin filler", "jawline injection"]) {
            return .init(
                category: .injectable,
                procedureDisplayName: "Jawline Filler",
                contextNote: "Jawline filler typically lasts 12–18 months.",
                retreatmentDays: 365,
                retreatmentRangeLabel: "~12 months",
                followUpMilestones: []
            )
        }
        if has(n, ["under eye filler", "tear trough", "periorbital filler", "undereye filler"]) {
            return .init(
                category: .injectable,
                procedureDisplayName: "Under Eye Filler",
                contextNote: "Under eye filler typically lasts 9–12 months.",
                retreatmentDays: 300,
                retreatmentRangeLabel: "~9–10 months",
                followUpMilestones: []
            )
        }
        if has(n, ["sculptra", "poly-l-lactic", "collagen stimulator"]) {
            return .init(
                category: .injectable,
                procedureDisplayName: "Sculptra",
                contextNote: "Sculptra builds gradually and lasts 2+ years. Most protocols require 2–3 sessions.",
                retreatmentDays: 365,
                retreatmentRangeLabel: "~12 months",
                followUpMilestones: []
            )
        }
        if has(n, ["kybella", "deoxycholic", "submental fat injection", "double chin injection"]) {
            return .init(
                category: .injectable,
                procedureDisplayName: "Kybella",
                contextNote: "Results are permanent, but a follow-up session may be recommended if needed.",
                retreatmentDays: 90,
                retreatmentRangeLabel: "~3 months",
                followUpMilestones: []
            )
        }
        if has(n, ["radiesse"]) {
            return .init(
                category: .injectable,
                procedureDisplayName: "Radiesse",
                contextNote: "Radiesse typically lasts 12–18 months.",
                retreatmentDays: 365,
                retreatmentRangeLabel: "~12 months",
                followUpMilestones: []
            )
        }
        if has(n, ["prp", "prf", "platelet rich", "vampire facial"]) {
            return .init(
                category: .injectable,
                procedureDisplayName: "PRP / PRF",
                contextNote: "PRP/PRF treatments are typically repeated every 3–6 months for best results.",
                retreatmentDays: 120,
                retreatmentRangeLabel: "~4 months",
                followUpMilestones: []
            )
        }
        // Generic filler catch-all (after all specific fillers above)
        if has(n, ["filler", "dermal filler", "hyaluronic", "juvederm", "restylane",
                   "belotero", "revanesse", "versa", "voluma", "vollure", "volbella"]) {
            return .init(
                category: .injectable,
                procedureDisplayName: "Dermal Filler",
                contextNote: "Filler typically lasts 6–18 months depending on product and treated area.",
                retreatmentDays: 270,
                retreatmentRangeLabel: "~9 months",
                followUpMilestones: []
            )
        }

        // ──────────────────────────────────────────────────────────
        // SKIN TREATMENTS — Facials & Energy Devices
        // ──────────────────────────────────────────────────────────
        if has(n, ["hydrafacial", "hydra facial"]) {
            return .init(
                category: .skinTreatment,
                procedureDisplayName: "HydraFacial",
                contextNote: "Monthly HydraFacials maintain skin hydration and clarity.",
                retreatmentDays: 30,
                retreatmentRangeLabel: "~1 month",
                followUpMilestones: []
            )
        }
        if has(n, ["microneedling", "micro-needling", "collagen induction", "dermapen", "skinpen"]) {
            return .init(
                category: .skinTreatment,
                procedureDisplayName: "Microneedling",
                contextNote: "Microneedling series are typically 3–6 sessions spaced 4–6 weeks apart.",
                retreatmentDays: 42,
                retreatmentRangeLabel: "~6 weeks",
                followUpMilestones: []
            )
        }
        if has(n, ["chemical peel", "vi peel", "jessner", "tca peel",
                   "glycolic peel", "salicylic peel", "lactic peel"]) {
            return .init(
                category: .skinTreatment,
                procedureDisplayName: "Chemical Peel",
                contextNote: "Light peels can be repeated every 4–6 weeks; medium peels every 3–6 months.",
                retreatmentDays: 45,
                retreatmentRangeLabel: "~6 weeks",
                followUpMilestones: []
            )
        }
        if has(n, ["laser resurfacing", "fraxel", "co2 laser", "erbium laser", "ablative laser",
                   "clear + brilliant", "clear and brilliant"]) {
            return .init(
                category: .skinTreatment,
                procedureDisplayName: "Laser Resurfacing",
                contextNote: "Ablative laser results last 1–3 years; follow-ups help maintain them.",
                retreatmentDays: 365,
                retreatmentRangeLabel: "~12 months",
                followUpMilestones: []
            )
        }
        if has(n, ["ipl", "intense pulsed light", "photofacial", "photo rejuvenation", "bbl photofacial"]) {
            return .init(
                category: .skinTreatment,
                procedureDisplayName: "IPL",
                contextNote: "IPL series are typically 3–5 sessions spaced 3–4 weeks apart.",
                retreatmentDays: 28,
                retreatmentRangeLabel: "~4 weeks",
                followUpMilestones: []
            )
        }
        if has(n, ["ultherapy", "ulthera", "ultrasound lift", "hifu"]) {
            return .init(
                category: .skinTreatment,
                procedureDisplayName: "Ultherapy / HIFU",
                contextNote: "Ultherapy / HIFU results typically last 1–2 years.",
                retreatmentDays: 365,
                retreatmentRangeLabel: "~12 months",
                followUpMilestones: []
            )
        }
        if has(n, ["thermage", "radiofrequency", "rf treatment", "profound", "morpheus", "forma", "inmode"]) {
            return .init(
                category: .skinTreatment,
                procedureDisplayName: "RF Treatment",
                contextNote: "Radiofrequency results typically last 1–2 years with maintenance sessions.",
                retreatmentDays: 365,
                retreatmentRangeLabel: "~12 months",
                followUpMilestones: []
            )
        }
        if has(n, ["coolsculpting", "cryolipolysis", "fat freezing", "sculpsure"]) {
            return .init(
                category: .skinTreatment,
                procedureDisplayName: "CoolSculpting",
                contextNote: "CoolSculpting results are long-lasting; additional cycles are sometimes done 6–8 weeks later.",
                retreatmentDays: 56,
                retreatmentRangeLabel: "~6–8 weeks",
                followUpMilestones: []
            )
        }
        if has(n, ["emsculpt", "body sculpting", "muscle stimulation"]) {
            return .init(
                category: .skinTreatment,
                procedureDisplayName: "Emsculpt",
                contextNote: "Emsculpt maintenance sessions are recommended every 3–6 months.",
                retreatmentDays: 120,
                retreatmentRangeLabel: "~4 months",
                followUpMilestones: []
            )
        }

        // ──────────────────────────────────────────────────────────
        // COSMETIC SURGERY
        // ──────────────────────────────────────────────────────────
        if has(n, ["rhinoplasty", "nose job", "nose surgery", "septoplasty", "rhinoplasty revision"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Rhinoplasty",
                contextNote: "Regular follow-ups let your surgeon monitor healing and swelling reduction.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week splint removal", days: 7),
                    .init(label: "1-month check-up", days: 30),
                    .init(label: "3-month check-up", days: 90),
                    .init(label: "6-month check-up", days: 180),
                    .init(label: "1-year final check-up", days: 365)
                ]
            )
        }
        if has(n, ["breast augmentation", "breast implant", "boob job", "breast aug",
                   "augmentation mammaplasty"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Breast Augmentation",
                contextNote: "Follow-ups monitor implant positioning and healing progress.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week check-up", days: 7),
                    .init(label: "6-week check-up", days: 42),
                    .init(label: "6-month check-up", days: 180),
                    .init(label: "1-year check-up", days: 365)
                ]
            )
        }
        if has(n, ["breast lift", "mastopexy"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Breast Lift",
                contextNote: "Post-op check-ups track scar healing and long-term lift results.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week check-up", days: 7),
                    .init(label: "6-week check-up", days: 42),
                    .init(label: "6-month check-up", days: 180),
                    .init(label: "1-year check-up", days: 365)
                ]
            )
        }
        if has(n, ["breast reduction", "reduction mammaplasty"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Breast Reduction",
                contextNote: "Post-op check-ups track scar healing and symptom relief.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week check-up", days: 7),
                    .init(label: "6-week check-up", days: 42),
                    .init(label: "6-month check-up", days: 180),
                    .init(label: "1-year check-up", days: 365)
                ]
            )
        }
        if has(n, ["facelift", "face lift", "rhytidectomy", "mini facelift", "deep plane", "smas lift"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Facelift",
                contextNote: "Follow-ups monitor scar maturation and long-term rejuvenation.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week check-up", days: 7),
                    .init(label: "1-month check-up", days: 30),
                    .init(label: "6-month check-up", days: 180),
                    .init(label: "1-year check-up", days: 365)
                ]
            )
        }
        if has(n, ["blepharoplasty", "eyelid surgery", "upper eyelid", "lower eyelid", "eyelid lift"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Blepharoplasty",
                contextNote: "Eyelid healing is closely monitored to ensure optimal function and appearance.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week suture removal", days: 7),
                    .init(label: "1-month check-up", days: 30),
                    .init(label: "6-month check-up", days: 180)
                ]
            )
        }
        if has(n, ["brow lift", "forehead lift", "endoscopic brow"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Brow Lift",
                contextNote: "Post-op check-ups track swelling reduction and nerve recovery.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week check-up", days: 7),
                    .init(label: "1-month check-up", days: 30),
                    .init(label: "6-month check-up", days: 180)
                ]
            )
        }
        if has(n, ["liposuction", "liposculpture", "vaser lipo", "smart lipo", "smartlipo",
                   "fat removal surgery"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Liposuction",
                contextNote: "Compression garment compliance and follow-ups are key to great contouring results.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week check-up", days: 7),
                    .init(label: "6-week check-up", days: 42),
                    .init(label: "3-month check-up", days: 90),
                    .init(label: "6-month check-up", days: 180)
                ]
            )
        }
        if has(n, ["tummy tuck", "abdominoplasty", "mini tummy tuck"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Tummy Tuck",
                contextNote: "Abdominal surgery requires follow-up to monitor wound healing and scar maturation.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week check-up", days: 7),
                    .init(label: "6-week check-up", days: 42),
                    .init(label: "3-month check-up", days: 90),
                    .init(label: "6-month check-up", days: 180)
                ]
            )
        }
        if has(n, ["bbl", "brazilian butt lift", "fat transfer buttock", "gluteal augmentation"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Brazilian Butt Lift",
                contextNote: "BBL follow-ups monitor fat survival and ensure proper positioning during healing.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week check-up", days: 7),
                    .init(label: "6-week check-up", days: 42),
                    .init(label: "3-month check-up", days: 90),
                    .init(label: "1-year check-up", days: 365)
                ]
            )
        }
        if has(n, ["mommy makeover", "body contouring surgery"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Mommy Makeover",
                contextNote: "Combined procedures require staged follow-ups for each treatment area.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week check-up", days: 7),
                    .init(label: "6-week check-up", days: 42),
                    .init(label: "3-month check-up", days: 90),
                    .init(label: "6-month check-up", days: 180),
                    .init(label: "1-year check-up", days: 365)
                ]
            )
        }
        if has(n, ["otoplasty", "ear surgery", "ear pinning"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Otoplasty",
                contextNote: "Ear surgery follow-ups monitor cartilage healing and suture sites.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week check-up", days: 7),
                    .init(label: "1-month check-up", days: 30),
                    .init(label: "6-month check-up", days: 180)
                ]
            )
        }
        if has(n, ["chin implant", "chin augmentation", "mentoplasty", "genioplasty"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Chin Augmentation",
                contextNote: "Follow-ups track implant positioning and incision healing.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week check-up", days: 7),
                    .init(label: "1-month check-up", days: 30),
                    .init(label: "6-month check-up", days: 180)
                ]
            )
        }
        if has(n, ["neck lift", "platysmaplasty"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Neck Lift",
                contextNote: "Neck lift follow-ups monitor platysma healing and contour.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week check-up", days: 7),
                    .init(label: "1-month check-up", days: 30),
                    .init(label: "6-month check-up", days: 180)
                ]
            )
        }
        if has(n, ["fat transfer", "fat grafting", "lipofilling"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Fat Transfer",
                contextNote: "Follow-ups monitor fat survival and final volume settling.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week check-up", days: 7),
                    .init(label: "6-week check-up", days: 42),
                    .init(label: "3-month check-up", days: 90),
                    .init(label: "6-month check-up", days: 180)
                ]
            )
        }
        // Generic surgical catch-all
        if has(n, ["surgery", "surgical", "implant", "augmentation", "plasty",
                   "ectomy", "otomy", "revision", "reconstruction"]) {
            return .init(
                category: .cosmeticSurgery,
                procedureDisplayName: "Surgery",
                contextNote: "Post-surgical follow-ups are important to monitor your healing progress.",
                retreatmentDays: nil,
                retreatmentRangeLabel: nil,
                followUpMilestones: [
                    .init(label: "1-week check-up", days: 7),
                    .init(label: "1-month check-up", days: 30),
                    .init(label: "6-month check-up", days: 180)
                ]
            )
        }

        // ──────────────────────────────────────────────────────────
        // FALLBACK
        // ──────────────────────────────────────────────────────────
        return .init(
            category: .other,
            procedureDisplayName: procedureName,
            contextNote: "Set a reminder to schedule your next appointment and keep your results fresh.",
            retreatmentDays: 180,
            retreatmentRangeLabel: "~6 months",
            followUpMilestones: []
        )
    }

    private static func has(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains(where: { text.contains($0) })
    }
}
