//
//  RecoveryPlanCopyPromptBuilder.swift
//  Renaissance Mobile
//

import Foundation

struct RecoveryPlanCopyPromptPackage: Equatable {
    let systemInstructions: String
    let userPrompt: String
    let schemaVersion: String
}

enum RecoveryPlanCopyPromptBuilder {
    static func build(
        input: RecoveryPlanInput,
        timelinePhase: RecoveryPlanTimelinePhase,
        journalSignals: RecoveryPlanJournalSignals?
    ) -> RecoveryPlanCopyPromptPackage {
        RecoveryPlanCopyPromptPackage(
            systemInstructions: systemInstructions,
            userPrompt: buildUserPrompt(
                input: input,
                timelinePhase: timelinePhase,
                journalSignals: journalSignals
            ),
            schemaVersion: "recovery_plan_copy_v1"
        )
    }

    private static var systemInstructions: String {
        """
        You write premium recovery roadmap copy for a cosmetic recovery app.

        Your job is to generate copy for one recovery phase only.

        Goals:
        - Be personalized to the user's actual procedure, phase, goals, body area, prior procedures, and health context.
        - Sound supportive, observant, and specific.
        - Focus on what is most useful right now in this phase.
        - Keep the tone grounded and premium, not robotic or overly clinical.

        Safety constraints:
        - Do not diagnose.
        - Do not give emergency or definitive medical instructions.
        - Do not claim certainty where recovery is variable.
        - Do not invent facts that were not provided.
        - Do not mention being an AI model.

        Output requirements:
        - Return valid JSON only.
        - Use exactly this shape:
          {
            "summary": "string",
            "focusAreas": ["string", "string", "string"]
          }
        - `summary` should be one short paragraph suitable for a compact teaser card.
        - `focusAreas` should contain 2 to 4 concise bullets.
        - Keep copy tight enough to fit a mobile teaser card.
        """
    }

    private static func buildUserPrompt(
        input: RecoveryPlanInput,
        timelinePhase: RecoveryPlanTimelinePhase,
        journalSignals: RecoveryPlanJournalSignals?
    ) -> String {
        var lines = [String]()

        lines.append("Generate copy for the current recovery roadmap phase using the structured context below.")
        lines.append("")
        lines.append("Procedure context:")
        lines.append("- Procedure name: \(input.procedureName)")
        lines.append("- Procedure family: \(input.procedureFamily.displayName)")
        lines.append("- Current phase title: \(timelinePhase.title)")
        lines.append("- Current phase status: \(timelinePhase.status.rawValue)")
        lines.append("- Current week: \(input.currentWeek)")
        lines.append("- Days since procedure: \(input.daysSinceProcedure)")
        lines.append("- Timeline summary: \(timelinePhase.summary)")

        lines.append("")
        lines.append("User profile context:")
        lines.append("- Aesthetic goals: \(listOrNone(input.aestheticGoals))")
        lines.append("- Body areas: \(listOrNone(input.bodyAreas))")
        lines.append("- Previous procedures: \(listOrNone(input.previousProcedures))")
        lines.append("- Health flags: \(listOrNone(input.healthFlags))")
        lines.append("- Procedures of interest: \(listOrNone(input.proceduresOfInterest))")
        lines.append("- Gender: \(valueOrNone(input.gender))")
        lines.append("- Age range: \(valueOrNone(input.ageRange))")
        lines.append("- Race / ethnicity: \(valueOrNone(input.raceEthnicity))")

        lines.append("")
        lines.append("Journal context:")
        if let journalSignals {
            lines.append("- Journal entry count: \(journalSignals.entryCount)")
            lines.append("- Weekly summary headline: \(valueOrNone(journalSignals.weeklySummaryHeadline))")
            lines.append("- Active alerts: \(listOrNone(journalSignals.activeAlerts))")
            lines.append("- Latest pain level: \(numericOrNone(journalSignals.latestPainLevel))")
            lines.append("- Latest swelling level: \(numericOrNone(journalSignals.latestSwellingLevel))")
            lines.append("- Latest bruising level: \(numericOrNone(journalSignals.latestBruisingLevel))")
            lines.append("- Latest redness level: \(numericOrNone(journalSignals.latestRednessLevel))")
        } else {
            lines.append("- No journal signals available")
        }

        lines.append("")
        lines.append("Writing instructions:")
        lines.append("- Personalize the summary to what matters most in this exact phase.")
        lines.append("- Reflect likely concerns at this stage for the procedure family.")
        lines.append("- If goals, prior procedures, or health flags are present, weave them in naturally.")
        lines.append("- Make the bullets actionable and specific, but not diagnostic.")
        lines.append("- Do not repeat the exact same sentence structure across all bullets.")

        return lines.joined(separator: "\n")
    }

    private static func listOrNone(_ values: [String]) -> String {
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? "None provided" : cleaned.joined(separator: ", ")
    }

    private static func valueOrNone(_ value: String?) -> String {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return "None provided"
        }
        return trimmed
    }

    private static func numericOrNone<T: LosslessStringConvertible>(_ value: T?) -> String {
        guard let value else { return "None provided" }
        return String(value)
    }
}

