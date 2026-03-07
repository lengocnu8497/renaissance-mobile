//
//  ReadinessData.swift
//  Renaissance Mobile
//
//  Clinical content sourced from ASPS (plasticsurgery.org), AAD (aad.org),
//  FDA prescribing information, and peer-reviewed dermatology literature.
//  This data is for informational purposes only. See disclaimer in ReadinessChecklistView.
//

import Foundation

// MARK: - Registry

struct ReadinessData {

    /// All available procedure checklists, keyed by id.
    static let all: [ProcedureChecklist] = [
        botox,
        lipFillers,
        microneedling,
        chemicalPeel,
        laserHairRemoval,
        microdermabrasion,
        hydrafacial,
        kybella,
        pdoThreadLift,
        laserResurfacing
    ]

    static func checklist(for procedureId: String) -> ProcedureChecklist? {
        all.first { $0.id == procedureId }
    }
}

// MARK: - Helpers

private func items(_ type: ChecklistSectionType, _ defs: [(String, Bool)]) -> ChecklistSection {
    ChecklistSection(
        id: type,
        items: defs.enumerated().map { i, def in
            ChecklistItem(id: "\(type.rawValue)_\(i)", text: def.0, isWarning: def.1)
        }
    )
}

// MARK: - 1. Botox / Neurotoxin

extension ReadinessData {
    static let botox = ProcedureChecklist(
        id: "botox",
        displayName: "Botox / Neurotoxin",
        category: "Injectables",
        sections: [
            items(.candidacy, [
                ("I am 18 years or older", false),
                ("I have dynamic wrinkles caused by muscle movement (forehead lines, frown lines, crow's feet)", false),
                ("I am NOT pregnant or breastfeeding", false),
                ("I do NOT have a neuromuscular disorder (myasthenia gravis, ALS, Lambert-Eaton syndrome)", false),
                ("I do NOT have an active skin infection or open wound at the treatment site", false),
                ("I am NOT currently taking aminoglycoside antibiotics (e.g. gentamicin)", false),
                ("I have realistic expectations — results are temporary (3–6 months)", false)
            ]),
            items(.preCare, [
                ("Avoid aspirin, ibuprofen, naproxen for 7–10 days before (increases bruising risk)", false),
                ("Avoid fish oil, vitamin E, and alcohol for 7 days before", false),
                ("Avoid herbal supplements (garlic, ginkgo, ginseng, St. John's Wort) for 2 weeks before", false),
                ("Stop topical retinoids and exfoliants on the treatment area 24–48 hours before", false),
                ("Avoid excessive sun exposure or sunburn to treatment area", false),
                ("Arrive with clean skin — no heavy makeup on treatment day", false),
                ("Inform your provider of all medications, supplements, and prior neurotoxin history", false)
            ]),
            items(.whatToExpect, [
                ("Procedure takes 10–20 minutes in-office with ultrafine needles", false),
                ("Mild pinching sensation; topical numbing cream available but usually not needed", false),
                ("Minor redness, swelling, or bruising at injection sites — resolves in 24–72 hours", false),
                ("Results begin appearing at 3–5 days; full effect at 10–14 days", false),
                ("Do not massage treated areas, lie face-down, or exercise vigorously for 4 hours after", false),
                ("Avoid heat (saunas, hot yoga) for 24 hours after", false),
                ("Avoid applying makeup for 4–6 hours after injection", false),
                ("Results typically last 3–6 months", false)
            ]),
            items(.redFlags, [
                ("Drooping eyelid (ptosis) or severe eyebrow asymmetry that is worsening", true),
                ("Difficulty swallowing, speaking, or breathing — call 911 immediately", true),
                ("Vision changes or double vision", true),
                ("Muscle weakness distant from the injection site", true),
                ("Signs of allergic reaction: hives, rash, wheezing, facial swelling, dizziness", true),
                ("Intense pain, unusual swelling, or fever at the injection site (possible infection)", true)
            ])
        ]
    )
}

// MARK: - 2. Lip Fillers / Dermal Fillers

extension ReadinessData {
    static let lipFillers = ProcedureChecklist(
        id: "lip_fillers",
        displayName: "Lip Fillers / Dermal Fillers",
        category: "Injectables",
        sections: [
            items(.candidacy, [
                ("I am 18 years or older (21+ commonly recommended for lips)", false),
                ("I am NOT pregnant or breastfeeding", false),
                ("I do NOT have an active cold sore (HSV) outbreak — must be fully resolved first", false),
                ("I do NOT have an active skin infection or acne in the treatment area", false),
                ("I have NOT had permanent fillers in the same area previously", false),
                ("I do NOT have a known allergy to hyaluronic acid or lidocaine", false),
                ("I understand results are temporary and may require touch-ups", false)
            ]),
            items(.preCare, [
                ("Avoid aspirin, ibuprofen, naproxen, vitamin E, and fish oil for 7–14 days before", false),
                ("Avoid alcohol for 7 days before (significantly increases bruising)", false),
                ("Avoid herbal blood thinners (ginkgo, garlic, ginseng) for 2 weeks before", false),
                ("If you have a history of cold sores (HSV), start antiviral medication 2–3 days before lip injections (ask your provider for a prescription)", false),
                ("Avoid dental procedures within 2 weeks before treatment", false),
                ("Stay well-hydrated in the days leading up to treatment", false),
                ("Arrive with clean skin; remove all makeup and lip products", false)
            ]),
            items(.whatToExpect, [
                ("Procedure takes 15–45 minutes; topical anesthetic or dental nerve block applied first", false),
                ("Significant swelling and bruising for lips, especially days 1–3", false),
                ("Final results are NOT assessable until 2 weeks post-injection when swelling resolves", false),
                ("Do not massage or press on the treated area unless directed by your provider", false),
                ("Avoid intense exercise for 24–48 hours and extreme heat for 48 hours", false),
                ("Sleep with head elevated on the first night", false),
                ("Avoid dental procedures for 2 weeks after injection", false),
                ("Results typically last 6–18 months depending on product and area", false)
            ]),
            items(.redFlags, [
                ("Blanching (white/pale skin), mottled purple pattern, or severe pain — this is a vascular emergency, contact your provider IMMEDIATELY", true),
                ("Vision changes or sudden vision loss — go to the ER immediately", true),
                ("Signs of infection: increasing redness, warmth, swelling after day 3–5, pus, or fever", true),
                ("Lumps or nodules appearing weeks after treatment (possible delayed reaction or biofilm)", true),
                ("Black, dark, or crusting skin in the treated area (possible tissue necrosis)", true)
            ])
        ]
    )
}

// MARK: - 3. Microneedling

extension ReadinessData {
    static let microneedling = ProcedureChecklist(
        id: "microneedling",
        displayName: "Microneedling",
        category: "Skin",
        sections: [
            items(.candidacy, [
                ("I am 18 years or older", false),
                ("I do NOT have active acne, rosacea flares, eczema, or psoriasis in the treatment area", false),
                ("I do NOT have a history of keloid scarring", false),
                ("I have NOT used isotretinoin (Accutane) within the last 6 months", false),
                ("I do NOT have an active cold sore (HSV) outbreak", false),
                ("I am NOT pregnant", false),
                ("I do NOT have a blood clotting disorder or take anticoagulant medication", false),
                ("I do NOT have an implanted pacemaker or defibrillator (relevant for RF microneedling only)", false)
            ]),
            items(.preCare, [
                ("Avoid aspirin, ibuprofen, naproxen, vitamin E, fish oil, and alcohol for 7 days before", false),
                ("Stop topical retinoids (tretinoin, retinol) 5–7 days before", false),
                ("Stop AHAs/BHAs (glycolic, salicylic acid) and benzoyl peroxide 5–7 days before", false),
                ("Avoid waxing, laser, or IPL treatments in the same area for 2 weeks before", false),
                ("Apply SPF 30+ sunscreen daily for 2+ weeks before (especially important for darker skin tones)", false),
                ("Arrive with clean, bare skin — no makeup or serums on treatment day", false),
                ("Inform provider of all medications and any recent procedures", false)
            ]),
            items(.whatToExpect, [
                ("Topical numbing cream is applied 20–30 minutes before the procedure", false),
                ("Procedure takes 30–60 minutes; mild pressure and scratching sensation", false),
                ("Pinpoint bleeding is normal and expected at therapeutic depths", false),
                ("Skin appears red and flushed (like a sunburn) immediately after", false),
                ("Mild swelling and possible pinpoint scabs at 24–48 hours", false),
                ("Skin may feel dry and flaky (peeling) around days 3–5", false),
                ("Use only gentle, fragrance-free moisturizer and mineral SPF for 3 days after — no actives", false),
                ("Results build over 4–6 weeks; a series of 3–6 sessions is typically recommended", false)
            ]),
            items(.redFlags, [
                ("Prolonged redness, swelling, or pain beyond 5–7 days (possible infection)", true),
                ("Pustules or yellow/green discharge from treated area", true),
                ("Fever or flu-like symptoms after the procedure", true),
                ("Raised, thickened, or firm scar tissue forming (keloid or hypertrophic scarring)", true),
                ("Unexpected dark patches forming during healing (hyperpigmentation)", true),
                ("Cold sore outbreak — treat immediately with antivirals and contact your provider", true)
            ])
        ]
    )
}

// MARK: - 4. Chemical Peel

extension ReadinessData {
    static let chemicalPeel = ProcedureChecklist(
        id: "chemical_peel",
        displayName: "Chemical Peel",
        category: "Skin",
        sections: [
            items(.candidacy, [
                ("I am 18 years or older", false),
                ("I have NOT used isotretinoin (Accutane) within the last 6 months", false),
                ("I do NOT have an active cold sore (HSV) outbreak", false),
                ("I do NOT have active inflammatory skin conditions (rosacea, eczema, psoriasis) in the treatment area", false),
                ("I am NOT pregnant or breastfeeding (especially for medium/deep peels)", false),
                ("I do NOT have a history of abnormal scarring (keloids)", false),
                ("I have NOT had facial surgery or laser resurfacing in the last 3–6 months", false),
                ("For medium/deep peels: I do NOT have cardiac arrhythmia or kidney/liver disease", false)
            ]),
            items(.preCare, [
                ("Follow your provider's 2–4 week pre-conditioning regimen if prescribed (tretinoin, SPF, hydroquinone)", false),
                ("Stop retinoids, AHAs, BHAs, and benzoyl peroxide 5–7 days before (unless provider instructs otherwise)", false),
                ("Avoid waxing, electrolysis, or laser/IPL in the treatment area for 2 weeks before", false),
                ("If you have a cold sore history: begin antiviral medication as directed before medium/deep peels", false),
                ("Avoid excessive sun and tanning for 4+ weeks before; use SPF 30+ daily", false),
                ("Avoid aspirin and NSAIDs for 7–10 days before (more relevant for deeper peels)", false),
                ("Arrange transportation home for medium/deep peels (significant immediate effects)", false)
            ]),
            items(.whatToExpect, [
                ("Superficial peel: 15–30 minutes, mild stinging, no downtime or 1–3 days of light flaking", false),
                ("Medium peel: 30–60 minutes, burning sensation and visible frosting, 7–10 days social downtime", false),
                ("Deep peel: 1–2 hours with sedation, significant swelling and crusting, 7–14+ days downtime", false),
                ("Avoid sun completely during healing; use only provider-specified gentle cleanser and moisturizer", false),
                ("Do NOT pick or peel the skin manually — this causes scarring", false),
                ("Use SPF 50+ daily once healed for at least 6 months", false)
            ]),
            items(.redFlags, [
                ("Signs of infection: increasing pain, pus, fever, rapidly spreading redness after day 3–4", true),
                ("Cold sore outbreak during healing — requires immediate antiviral treatment", true),
                ("Raised or thick scar tissue forming", true),
                ("Severe or unusual allergic reaction (hives, anaphylaxis)", true),
                ("Dramatic skin color changes (extreme lightening or darkening) in treated area", true)
            ])
        ]
    )
}

// MARK: - 5. Laser Hair Removal

extension ReadinessData {
    static let laserHairRemoval = ProcedureChecklist(
        id: "laser_hair_removal",
        displayName: "Laser Hair Removal",
        category: "Body",
        sections: [
            items(.candidacy, [
                ("I am 18 years or older", false),
                ("I do NOT have a fresh tan, recent sunburn, or self-tanner applied to the treatment area within 4–6 weeks", false),
                ("I do NOT have light blonde, gray, red, or white hair in the treatment area (insufficient melanin for laser targeting)", false),
                ("I am NOT taking photosensitizing medications (doxycycline, tetracycline, certain SSRIs — check with your provider)", false),
                ("I have NOT used isotretinoin (Accutane) within the last 6 months", false),
                ("I do NOT have a history of keloid scarring", false),
                ("I am NOT pregnant", false),
                ("I do NOT have tattoos in the treatment area", false)
            ]),
            items(.preCare, [
                ("Avoid waxing, plucking, threading, or electrolysis for 4–6 weeks before — shaving is fine and required", false),
                ("Shave the treatment area 24 hours before your appointment", false),
                ("Avoid sun exposure, tanning beds, and self-tanners for 4–6 weeks before each session; use SPF 30+ daily", false),
                ("Discontinue photosensitizing medications at least 1–2 weeks before if medically possible (consult your prescribing doctor)", false),
                ("Avoid retinoids and AHAs on the treatment area for 5–7 days before", false),
                ("Do NOT apply deodorant, lotion, or any products to the treatment area on the day of your appointment", false)
            ]),
            items(.whatToExpect, [
                ("Each session is 15 minutes to 2 hours depending on the treatment area", false),
                ("Cooling system or chilled gel is applied; laser pulses feel like a rubber band snap", false),
                ("Redness and mild swelling (like a mild sunburn) immediately after — resolves within 1–24 hours", false),
                ("Small bumps around follicles are normal and resolve within 24–48 hours", false),
                ("Hair 'sheds' over 1–3 weeks post-session — this is normal", false),
                ("Apply aloe vera or provider-recommended soothing lotion; avoid heat and sweating for 24–48 hours", false),
                ("Multiple sessions required (typically 6–8+), spaced 4–12 weeks apart", false)
            ]),
            items(.redFlags, [
                ("Blistering, crusting, or burns beyond the treated follicular area", true),
                ("Significant skin darkening or lightening (hyperpigmentation or hypopigmentation) — especially concerning for darker skin tones", true),
                ("Signs of infection: increasing pain, pus, fever, spreading redness", true),
                ("Scarring or raised scar tissue formation", true),
                ("Eye pain or vision changes if treatment was near the eye area", true)
            ])
        ]
    )
}

// MARK: - 6. Microdermabrasion

extension ReadinessData {
    static let microdermabrasion = ProcedureChecklist(
        id: "microdermabrasion",
        displayName: "Microdermabrasion",
        category: "Skin",
        sections: [
            items(.candidacy, [
                ("I am 18 years or older", false),
                ("I do NOT have active inflammatory acne with open lesions in the treatment area", false),
                ("I do NOT have active rosacea, eczema, or psoriasis flares in the treatment area", false),
                ("I do NOT have an active cold sore (HSV) outbreak", false),
                ("I have NOT used isotretinoin (Accutane) within the last 6 months", false),
                ("I do NOT have open wounds, cuts, or recent sunburn in the treatment area", false)
            ]),
            items(.preCare, [
                ("Avoid topical retinoids, AHAs/BHAs, and benzoyl peroxide for 3–5 days before", false),
                ("Avoid sun exposure and tanning; use SPF 30+ daily leading up to treatment", false),
                ("Do not wax, thread, or use depilatory creams on the treatment area for at least 1 week before", false),
                ("Arrive with clean, bare skin — no makeup or skincare products on treatment day", false),
                ("Avoid alcohol for 24 hours before", false)
            ]),
            items(.whatToExpect, [
                ("Procedure takes 30–60 minutes; a handheld device gently abrades and vacuums dead skin cells", false),
                ("Mild scratching and suction sensation — no anesthesia required", false),
                ("Skin appears pink or slightly red immediately after; redness typically resolves within 1–4 hours", false),
                ("Light flaking or dryness for 24–48 hours is normal", false),
                ("Often called a 'lunchtime procedure' — minimal to no social downtime", false),
                ("Apply gentle moisturizer and mineral SPF after treatment; avoid sun for 24 hours", false),
                ("Results are subtle and cumulative; a series of 5–10 sessions is typically recommended", false)
            ]),
            items(.redFlags, [
                ("Persistent redness, swelling, or pain beyond 48–72 hours", true),
                ("Signs of infection: warmth, pus, fever, rapidly spreading redness", true),
                ("Unusual skin darkening or lightening patches forming", true),
                ("Cold sore outbreak following treatment — treat immediately with antivirals", true)
            ])
        ]
    )
}

// MARK: - 7. HydraFacial

extension ReadinessData {
    static let hydrafacial = ProcedureChecklist(
        id: "hydrafacial",
        displayName: "HydraFacial",
        category: "Facials",
        sections: [
            items(.candidacy, [
                ("I am 18 years or older (teens may be treated with parental consent for acne management)", false),
                ("I do NOT have an active cold sore (HSV) outbreak", false),
                ("I do NOT have open wounds, active acne cysts, or severe inflammatory acne in the treatment area", false),
                ("I have NOT had facial surgery, injectables, or laser procedures within the last 1–2 weeks", false),
                ("I do NOT have a known allergy to salicylic acid (relevant for acne-focused protocols)", false),
                ("If pregnant: inform your provider — some serum ingredients require provider review", false)
            ]),
            items(.preCare, [
                ("Avoid retinoids, AHAs/BHAs for 3–5 days before", false),
                ("Avoid sun exposure and tanning for at least 1 week before; use SPF 30+", false),
                ("No waxing or facial hair removal for 1 week before", false),
                ("Arrive with clean skin; remove makeup and contact lenses if treatment is near the eye area", false),
                ("Stay well-hydrated for optimal results", false)
            ]),
            items(.whatToExpect, [
                ("Procedure takes 30–60 minutes; no needles and no significant discomfort", false),
                ("Multi-step treatment: cleanse and mild peel, pore extraction, serum infusion", false),
                ("Skin appears immediately brighter and more hydrated after treatment", false),
                ("Minimal to no redness; any redness resolves within 1–2 hours", false),
                ("No downtime — a genuine 'lunchtime' procedure", false),
                ("Avoid retinoids and active acids for 24 hours after; apply SPF", false),
                ("Monthly maintenance sessions are typically recommended", false)
            ]),
            items(.redFlags, [
                ("Prolonged or unusual redness, swelling, or hives (possible serum ingredient sensitivity or allergic reaction)", true),
                ("Cold sore outbreak following treatment — treat immediately with antivirals", true),
                ("Signs of skin infection: fever, spreading redness, warmth, discharge", true),
                ("Unusual skin darkening or burning sensation persisting beyond 24 hours", true)
            ])
        ]
    )
}

// MARK: - 8. Kybella

extension ReadinessData {
    static let kybella = ProcedureChecklist(
        id: "kybella",
        displayName: "Kybella (Submental Fat Reduction)",
        category: "Injectables",
        sections: [
            items(.candidacy, [
                ("I am 18 years or older", false),
                ("My submental fullness ('double chin') is caused by excess FAT — not primarily by loose skin or muscle banding", false),
                ("I have adequate skin elasticity (skin that will contract after fat is reduced)", false),
                ("I am NOT pregnant or breastfeeding", false),
                ("I do NOT have an active infection or skin condition in the chin/neck area", false),
                ("I have NOT had surgical procedures to the neck (submentoplasty, liposuction) — inform your provider if you have", false),
                ("I do NOT have difficulty swallowing (dysphagia)", false),
                ("I understand that 2–6 sessions are typically needed, spaced 4–8 weeks apart", false)
            ]),
            items(.preCare, [
                ("Avoid aspirin, ibuprofen, naproxen, vitamin E, fish oil, and alcohol for 7–10 days before (significant swelling is expected — minimizing blood thinners reduces severity)", false),
                ("Avoid dental procedures 1–2 weeks before", false),
                ("Arrive with clean skin; shave any beard stubble in the chin/neck area", false),
                ("Arrange transportation home — significant swelling can occur rapidly", false),
                ("Plan 2–4 days of social downtime after treatment (swelling can be dramatic)", false),
                ("Inform provider of all medications and any history of neck surgery", false)
            ]),
            items(.whatToExpect, [
                ("Procedure takes 15–20 minutes; a grid is drawn on the chin and 20+ small injections are made", false),
                ("Burning sensation during and immediately after injection is expected and normal", false),
                ("Swelling is SIGNIFICANT and expected — the area may look temporarily worse before improving", false),
                ("Swelling, bruising, numbness, and firmness peak at 24–72 hours and resolve over 4–6 weeks", false),
                ("Numbness in the area can persist for several weeks — this is normal", false),
                ("Final assessment of results is NOT possible until 4–6 weeks after each session", false),
                ("A compression garment (chin strap) may be recommended to manage swelling", false)
            ]),
            items(.redFlags, [
                ("Uneven smile, drooping at the corner of the mouth, or facial muscle weakness — possible nerve impact, contact provider immediately", true),
                ("Difficulty swallowing — important safety signal; contact provider immediately", true),
                ("Severe or worsening pain beyond normal swelling discomfort after day 3–4", true),
                ("Skin ulceration, open sores, or darkening of skin in the treatment area (possible tissue damage)", true),
                ("Signs of infection: fever, rapidly expanding redness, warmth, pus", true),
                ("Hair loss at the injection site — a documented side effect requiring provider evaluation", true)
            ])
        ]
    )
}

// MARK: - 9. PDO Thread Lift

extension ReadinessData {
    static let pdoThreadLift = ProcedureChecklist(
        id: "pdo_thread_lift",
        displayName: "PDO Thread Lift",
        category: "Non-Surgical",
        sections: [
            items(.candidacy, [
                ("I am 18 years or older (typically best for ages 30–65)", false),
                ("I have MILD TO MODERATE skin laxity — I understand threads do not replicate surgical facelift results", false),
                ("I do NOT have active skin infection, acne, or inflammation in the treatment area", false),
                ("I am NOT pregnant or breastfeeding", false),
                ("I do NOT have a history of keloid formation", false),
                ("I have NOT had Botox or filler in the same area within the last 2 weeks", false),
                ("I am NOT currently undergoing active cancer treatment", false),
                ("I am a non-smoker or willing to stop smoking 2–4 weeks before and after", false)
            ]),
            items(.preCare, [
                ("Avoid aspirin, ibuprofen, naproxen, vitamin E, fish oil, and alcohol for 7–10 days before (bruising and hematoma risk is significant with thread procedures)", false),
                ("Avoid herbal anticoagulants (ginkgo, garlic, ginseng) for 2 weeks before", false),
                ("Avoid dental procedures 2 weeks before AND after treatment", false),
                ("Eat a meal before your appointment (to help prevent lightheadedness)", false),
                ("Plan for 1–2 weeks of social downtime (bruising, swelling, and possible visible lines)", false),
                ("Inform provider of all medications and supplements", false)
            ]),
            items(.whatToExpect, [
                ("Procedure takes 30–90 minutes with local anesthesia; pressure and pulling sensation is normal", false),
                ("Immediately after: swelling, bruising, and skin dimpling/puckering at insertion points — this is normal and resolves as swelling subsides", false),
                ("Days 1–3: most significant swelling and bruising; social downtime strongly recommended", false),
                ("Avoid extreme facial expressions, chewing hard foods, dental work, and facial massage for 2 weeks", false),
                ("Sleep face-up (back sleeping) for at least 2 weeks; do not lie on the treated side", false),
                ("Dimpling and puckering typically resolve within 2–4 weeks", false),
                ("Full results visible at 4–6 weeks; collagen stimulation continues as PDO dissolves over 6 months", false),
                ("Results typically last 12–18 months", false)
            ]),
            items(.redFlags, [
                ("Thread visibility or protrusion through the skin (thread extrusion) — requires prompt removal by provider", true),
                ("Signs of infection: fever, warmth, spreading redness, discharge, increasing pain", true),
                ("Rapidly expanding, painful swelling under the skin (possible hematoma)", true),
                ("Unexpected facial numbness, tingling, or muscle weakness (possible nerve impact)", true),
                ("Severe or persistent facial asymmetry beyond 4–6 weeks", true),
                ("Visible cord-like structure that has moved from original placement (thread migration)", true)
            ])
        ]
    )
}

// MARK: - 10. Laser Skin Resurfacing (Fraxel / CO2)

extension ReadinessData {
    static let laserResurfacing = ProcedureChecklist(
        id: "laser_resurfacing",
        displayName: "Laser Skin Resurfacing",
        category: "Non-Surgical",
        sections: [
            items(.candidacy, [
                ("I am 18 years or older", false),
                ("I have NOT used isotretinoin (Accutane) within the last 6–12 months (12 months required for ablative lasers)", false),
                ("I do NOT have an active cold sore (HSV) outbreak — antiviral prophylaxis is REQUIRED for all patients undergoing resurfacing", false),
                ("I do NOT have active inflammatory skin conditions in the treatment area", false),
                ("I am NOT pregnant or breastfeeding", false),
                ("I do NOT have a history of keloid or hypertrophic scarring", false),
                ("I have NOT had radiation to the face within the past 12 months", false),
                ("For ablative CO2: my skin type is Fitzpatrick I–III (darker skin types carry significantly higher risk)", false)
            ]),
            items(.preCare, [
                ("Follow the 4–6 week pre-conditioning skin regimen prescribed by your provider (tretinoin, hydroquinone, SPF)", false),
                ("Begin antiviral medication (e.g. valacyclovir) 1–2 days before as directed by your provider — this is required for ALL resurfacing patients", false),
                ("Avoid aspirin, NSAIDs, vitamin E, blood thinners, and alcohol for 7–14 days before", false),
                ("Avoid sun exposure and tanning for 4–6 weeks before; arrive with untanned skin", false),
                ("Avoid other facial laser, IPL, chemical peel, or injectable treatments for 2–4 weeks before", false),
                ("Stop retinoids 5–7 days before treatment day (per provider instruction)", false),
                ("Arrange transportation home (sedation is commonly used for ablative procedures)", false),
                ("Plan 5–14+ days of home recovery time for ablative treatments", false),
                ("Prepare post-laser supplies: provider-prescribed ointment, gentle cleanser, ice packs, SPF 50+", false)
            ]),
            items(.whatToExpect, [
                ("Non-ablative Fraxel: 20–40 minutes, mild-moderate stinging, 3–5 days social downtime", false),
                ("Ablative fractional CO2: 30–90 minutes with sedation, 7–14 days social downtime minimum", false),
                ("Significant redness and swelling after ablative procedures — periorbital area may swell considerably", false),
                ("Strict wound care required: regular soaks, ointment reapplication, no picking or peeling", false),
                ("Redness persists for weeks to months after ablative treatment — mineral makeup can cover once healed", false),
                ("Avoid sun completely during healing; wear SPF 50+ every day once healed", false),
                ("No retinoids or active acids until provider clears (typically 4–8 weeks post-ablative)", false),
                ("Full recovery and final results may take 3–6 months for ablative treatments", false)
            ]),
            items(.redFlags, [
                ("Cold sore outbreak during healing — requires immediate aggressive antiviral treatment; delayed treatment can cause scarring", true),
                ("Signs of bacterial infection: increasing pain, fever, pus, foul odor, spreading redness (impetigo and MRSA are documented risks post-resurfacing)", true),
                ("Scarring or hypertrophic scar formation during healing", true),
                ("Significant white or dark patches (hypopigmentation or hyperpigmentation) appearing 6–8 weeks post-treatment", true),
                ("Prolonged oozing, weeping, or crusting beyond the expected healing timeline", true),
                ("Eye pain, vision changes, or severe periorbital swelling", true),
                ("Widespread itching rash during healing (possible contact dermatitis to wound care products)", true)
            ])
        ]
    )
}
