//
//  PhotoAngleGuideService.swift
//  Renaissance Mobile
//
//  Maps (procedureName, weekNumber) → WeeklyPhotoGuide containing
//  ordered PhotoAnglePrompts and a contextual note.
//
//  Uses the same keyword-matching pattern as ProcedureReminderConfig.
//

import Foundation

struct PhotoAngleGuideService {

    static func guide(for procedureName: String, week: Int) -> WeeklyPhotoGuide {
        let n = procedureName.lowercased()

        // ── Rhinoplasty ────────────────────────────────────────────────────────
        if has(n, ["rhinoplasty", "nose job", "septoplasty", "nose surgery"]) {
            let core: [PhotoAnglePrompt] = [
                .init(angle: .front,        instruction: "Face forward, chin parallel to floor"),
                .init(angle: .leftProfile,  instruction: "Turn fully left, keep chin level"),
                .init(angle: .rightProfile, instruction: "Turn fully right, keep chin level"),
                .init(angle: .underChin,    instruction: "Tilt head back slightly, camera below chin")
            ]
            let extended = core + [
                .init(angle: .leftThreeQuarter,  instruction: "Turn 45° left from front"),
                .init(angle: .rightThreeQuarter, instruction: "Turn 45° right from front")
            ]
            let note: String
            if week <= 2      { note = "Peak swelling in weeks 1–2. Capture all angles consistently." }
            else if week <= 6 { note = "Swelling resolving — tip definition becomes visible week by week." }
            else              { note = "Final shape is emerging. Continue consistent documentation." }
            return WeeklyPhotoGuide(weekNumber: week, procedureName: procedureName, contextNote: note, angles: week <= 4 ? core : extended)
        }

        // ── Botox / Neurotoxins ────────────────────────────────────────────────
        if has(n, ["botox", "dysport", "xeomin", "jeuveau", "daxxify", "neurotoxin", "neuromodulator"]) {
            let angles: [PhotoAnglePrompt] = [
                .init(angle: .front,      instruction: "Relax your face completely, look straight ahead"),
                .init(angle: .smileFull,  instruction: "Give a full natural smile"),
                .init(angle: .browRaised, instruction: "Raise your eyebrows as high as you can")
            ]
            let note = week == 1
                ? "Botox takes 7–14 days for full effect. Capture expressions consistently each week."
                : "Compare your expression range to Week 1 photos."
            return WeeklyPhotoGuide(weekNumber: week, procedureName: procedureName, contextNote: note, angles: angles)
        }

        // ── Lip Filler ─────────────────────────────────────────────────────────
        if has(n, ["lip filler", "lip augmentation", "lip injection"]) {
            let angles: [PhotoAnglePrompt] = [
                .init(angle: .front,       instruction: "Lips relaxed, no expression"),
                .init(angle: .smileNeutral, instruction: "Natural soft smile"),
                .init(angle: .closeUpLips, instruction: "Close up — fill frame with your lips")
            ]
            let note = week == 1
                ? "Swelling peaks in week 1. Final shape settles after 2 weeks."
                : "Compare lip volume and shape to your Week 1 photos."
            return WeeklyPhotoGuide(weekNumber: week, procedureName: procedureName, contextNote: note, angles: angles)
        }

        // ── Cheek / Midface Filler ─────────────────────────────────────────────
        if has(n, ["cheek filler", "midface filler", "cheek augmentation", "malar filler"]) {
            let angles: [PhotoAnglePrompt] = [
                .init(angle: .front,             instruction: "Face forward, neutral expression"),
                .init(angle: .leftThreeQuarter,  instruction: "Turn 45° left from front"),
                .init(angle: .rightThreeQuarter, instruction: "Turn 45° right from front")
            ]
            return WeeklyPhotoGuide(weekNumber: week, procedureName: procedureName, contextNote: "Cheek filler settles over 2–4 weeks as swelling resolves.", angles: angles)
        }

        // ── Jawline / Chin Filler ──────────────────────────────────────────────
        if has(n, ["jawline filler", "jaw filler", "chin filler"]) {
            let angles: [PhotoAnglePrompt] = [
                .init(angle: .front,       instruction: "Face forward, neutral expression"),
                .init(angle: .leftProfile,  instruction: "Turn fully left"),
                .init(angle: .rightProfile, instruction: "Turn fully right")
            ]
            return WeeklyPhotoGuide(weekNumber: week, procedureName: procedureName, contextNote: "Jawline definition becomes clearer as swelling resolves over 1–2 weeks.", angles: angles)
        }

        // ── Under Eye Filler ───────────────────────────────────────────────────
        if has(n, ["under eye filler", "tear trough", "periorbital filler", "undereye"]) {
            let angles: [PhotoAnglePrompt] = [
                .init(angle: .front,       instruction: "Face forward, relax completely, even lighting"),
                .init(angle: .closeUpEyes, instruction: "Close up of the under-eye area")
            ]
            return WeeklyPhotoGuide(weekNumber: week, procedureName: procedureName, contextNote: "Under-eye filler settles over 2–3 weeks as swelling reduces.", angles: angles)
        }

        // ── Facelift / Neck Lift ───────────────────────────────────────────────
        if has(n, ["facelift", "face lift", "rhytidectomy", "neck lift", "necklift", "lower facelift"]) {
            let angles: [PhotoAnglePrompt] = [
                .init(angle: .front,             instruction: "Face forward, neutral expression"),
                .init(angle: .leftProfile,        instruction: "Turn fully left"),
                .init(angle: .rightProfile,       instruction: "Turn fully right"),
                .init(angle: .leftThreeQuarter,   instruction: "45° from front to the left"),
                .init(angle: .rightThreeQuarter,  instruction: "45° from front to the right")
            ]
            let note = week <= 2
                ? "Significant swelling and bruising expected in the first 2 weeks."
                : "Swelling is improving — jawline and neck contour becomes visible."
            return WeeklyPhotoGuide(weekNumber: week, procedureName: procedureName, contextNote: note, angles: angles)
        }

        // ── Blepharoplasty / Eyelid ────────────────────────────────────────────
        if has(n, ["blepharoplasty", "eyelid", "eye lift", "upper bleph", "lower bleph"]) {
            let angles: [PhotoAnglePrompt] = [
                .init(angle: .front,       instruction: "Eyes fully open, neutral expression"),
                .init(angle: .closeUpEyes, instruction: "Close up — eyes open, fill frame with eye area"),
                .init(angle: .front,       instruction: "Eyes gently closed, relax completely")
            ]
            let note = week <= 2
                ? "Bruising and swelling around the eyes peak in week 1."
                : "Scar lines are fading — compare crease definition to earlier weeks."
            return WeeklyPhotoGuide(weekNumber: week, procedureName: procedureName, contextNote: note, angles: angles)
        }

        // ── Breast Surgery (all types) ─────────────────────────────────────────
        if has(n, ["breast surgery", "breast augmentation", "breast aug", "breast implant",
                   "breast lift", "breast reduction", "mastopexy", "augmentation mammoplasty"]) {
            let angles: [PhotoAnglePrompt] = [
                .init(angle: .front,       instruction: "Arms relaxed at sides, face forward"),
                .init(angle: .lateral,     instruction: "Turn fully to the side, arm slightly forward"),
                .init(angle: .decolletage, instruction: "Slight downward angle from above, chest in frame")
            ]
            let note = week <= 3
                ? "Implants appear high and tight initially — they drop and soften over 3–6 months."
                : "Shape is settling. Track the drop-and-fluff progress each week."
            return WeeklyPhotoGuide(weekNumber: week, procedureName: procedureName, contextNote: note, angles: angles)
        }

        // ── Body Contouring ────────────────────────────────────────────────────
        if has(n, ["body contouring", "liposuction", "lipo", "tummy tuck", "abdominoplasty",
                   "bbl", "brazilian butt lift", "body sculpt"]) {
            let angles: [PhotoAnglePrompt] = [
                .init(angle: .front,       instruction: "Stand upright, arms slightly away from sides"),
                .init(angle: .leftProfile,  instruction: "Turn fully left, arms slightly forward"),
                .init(angle: .rightProfile, instruction: "Turn fully right, arms slightly forward"),
                .init(angle: .lateral,      instruction: "Side view — keep posture natural and relaxed")
            ]
            let note: String
            if week <= 2      { note = "Significant swelling under compression garment — stay consistent with angles." }
            else if week <= 6 { note = "Swelling slowly reducing. Garment still important for tracking." }
            else              { note = "Final contours becoming visible as swelling resolves." }
            return WeeklyPhotoGuide(weekNumber: week, procedureName: procedureName, contextNote: note, angles: angles)
        }

        // ── Facial Surgery (facelift, brow lift, combo) ────────────────────────
        if has(n, ["facial surgery", "brow lift", "browlift", "forehead lift", "mid-facelift",
                   "midface lift", "combo facial"]) {
            let angles: [PhotoAnglePrompt] = [
                .init(angle: .front,            instruction: "Face forward, neutral expression, even lighting"),
                .init(angle: .leftProfile,       instruction: "Turn fully left"),
                .init(angle: .rightProfile,      instruction: "Turn fully right"),
                .init(angle: .leftThreeQuarter,  instruction: "45° from front to the left"),
                .init(angle: .rightThreeQuarter, instruction: "45° from front to the right")
            ]
            let note: String
            if week <= 2      { note = "Bruising and swelling are heaviest in the first two weeks. Rest fully." }
            else if week <= 4 { note = "Swelling is resolving — early results becoming visible." }
            else              { note = "Movement and expression are returning to normal." }
            return WeeklyPhotoGuide(weekNumber: week, procedureName: procedureName, contextNote: note, angles: angles)
        }

        // ── Skincare Treatments (generic) ─────────────────────────────────────
        if has(n, ["hydrafacial", "facial", "peel", "laser", "microneedling", "prp", "prf"]) {
            let angles: [PhotoAnglePrompt] = [
                .init(angle: .front,             instruction: "Face forward, natural lighting"),
                .init(angle: .leftThreeQuarter,  instruction: "45° left — capture skin texture"),
                .init(angle: .rightThreeQuarter, instruction: "45° right — capture skin texture")
            ]
            return WeeklyPhotoGuide(weekNumber: week, procedureName: procedureName, contextNote: "Consistent lighting and angles help you track skin improvements week over week.", angles: angles)
        }

        // ── Generic fallback ───────────────────────────────────────────────────
        let fallback: [PhotoAnglePrompt] = [
            .init(angle: .front,        instruction: "Face forward, neutral expression, consistent lighting"),
            .init(angle: .leftProfile,  instruction: "Turn fully left"),
            .init(angle: .rightProfile, instruction: "Turn fully right")
        ]
        return WeeklyPhotoGuide(
            weekNumber: week,
            procedureName: procedureName,
            contextNote: "Same lighting and angles each week gives you the clearest before/after comparison.",
            angles: fallback
        )
    }

    private static func has(_ name: String, _ keywords: [String]) -> Bool {
        keywords.contains { name.contains($0) }
    }
}
