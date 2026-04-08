//
//  RecoveryPlanGeneratedCopyValidator.swift
//  Renaissance Mobile
//

import Foundation

enum RecoveryPlanGeneratedCopyValidationError: LocalizedError {
    case emptySummary
    case summaryTooLong
    case invalidFocusAreaCount
    case containsEmptyFocusArea
    case containsDiagnosticLanguage
    case contradictsCurrentPhaseTiming
    case referencesMissingContext(String)

    var errorDescription: String? {
        switch self {
        case .emptySummary:
            return "Generated recovery plan copy had an empty summary."
        case .summaryTooLong:
            return "Generated recovery plan summary was too long for the teaser card."
        case .invalidFocusAreaCount:
            return "Generated recovery plan copy must contain between 2 and 4 focus areas."
        case .containsEmptyFocusArea:
            return "Generated recovery plan copy contained an empty focus area."
        case .containsDiagnosticLanguage:
            return "Generated recovery plan copy contained disallowed diagnostic language."
        case .contradictsCurrentPhaseTiming:
            return "Generated recovery plan copy contradicted the current phase timing."
        case .referencesMissingContext(let field):
            return "Generated recovery plan copy referenced missing context: \(field)."
        }
    }
}

enum RecoveryPlanGeneratedCopyValidator {
    private static let maxSummaryLength = 380
    private static let disallowedPhrases = [
        "you have an infection",
        "this is definitely an infection",
        "you are experiencing necrosis",
        "you have necrosis",
        "this confirms",
        "this means you need emergency care",
        "diagnosis",
        "diagnosed",
        "medically certain"
    ]

    static func validate(
        _ copy: RecoveryPlanGeneratedCopy,
        input: RecoveryPlanInput,
        timelinePhase: RecoveryPlanTimelinePhase
    ) throws -> RecoveryPlanGeneratedCopy {
        let sanitized = sanitize(copy)

        guard !sanitized.summary.isEmpty else {
            throw RecoveryPlanGeneratedCopyValidationError.emptySummary
        }

        guard sanitized.summary.count <= maxSummaryLength else {
            throw RecoveryPlanGeneratedCopyValidationError.summaryTooLong
        }

        guard (2...4).contains(sanitized.focusAreas.count) else {
            throw RecoveryPlanGeneratedCopyValidationError.invalidFocusAreaCount
        }

        guard !sanitized.focusAreas.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw RecoveryPlanGeneratedCopyValidationError.containsEmptyFocusArea
        }

        let searchableText = ([sanitized.summary] + sanitized.focusAreas).joined(separator: " ").lowercased()

        if disallowedPhrases.contains(where: { searchableText.contains($0) }) {
            throw RecoveryPlanGeneratedCopyValidationError.containsDiagnosticLanguage
        }

        if contradictsPhaseTiming(text: searchableText, input: input, timelinePhase: timelinePhase) {
            throw RecoveryPlanGeneratedCopyValidationError.contradictsCurrentPhaseTiming
        }

        try validateContextReferences(in: searchableText, input: input)

        return sanitized
    }

    static func sanitize(_ copy: RecoveryPlanGeneratedCopy) -> RecoveryPlanGeneratedCopy {
        let normalized = copy.normalized
        let summary = collapseWhitespace(in: normalized.summary)
        let focusAreas = dedupePreservingOrder(
            normalized.focusAreas.map { collapseWhitespace(in: $0) }
        )

        return RecoveryPlanGeneratedCopy(summary: summary, focusAreas: focusAreas)
    }

    private static func validateContextReferences(
        in text: String,
        input: RecoveryPlanInput
    ) throws {
        if input.previousProcedures.isEmpty,
           text.contains("prior procedure") || text.contains("previous procedure history") {
            throw RecoveryPlanGeneratedCopyValidationError.referencesMissingContext("previous procedures")
        }

        if input.healthFlags.isEmpty,
           text.contains("health flag") || text.contains("health consideration") || text.contains("health context") {
            throw RecoveryPlanGeneratedCopyValidationError.referencesMissingContext("health flags")
        }

        if input.aestheticGoals.isEmpty,
           text.contains("your goals") || text.contains("aesthetic goals") {
            throw RecoveryPlanGeneratedCopyValidationError.referencesMissingContext("aesthetic goals")
        }

        if input.bodyAreas.isEmpty,
           text.contains("body area") || text.contains("treatment area") {
            throw RecoveryPlanGeneratedCopyValidationError.referencesMissingContext("body areas")
        }
    }

    private static func contradictsPhaseTiming(
        text: String,
        input: RecoveryPlanInput,
        timelinePhase: RecoveryPlanTimelinePhase
    ) -> Bool {
        if timelinePhase.status == .current {
            if input.currentWeek >= 3 {
                let earlyPhasePhrases = [
                    "day 1",
                    "day one",
                    "immediately after surgery",
                    "right after surgery",
                    "the first few days after surgery",
                    "week 1 only"
                ]
                if earlyPhasePhrases.contains(where: { text.contains($0) }) {
                    return true
                }
            }

            if text.contains("completed phase") || text.contains("this phase is behind you") {
                return true
            }
        }

        return false
    }

    private static func collapseWhitespace(in text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: "..", with: ".")
            .replacingOccurrences(of: " ,", with: ",")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func dedupePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered = [String]()

        for value in values {
            let key = value.lowercased()
            guard !value.isEmpty, seen.insert(key).inserted else { continue }
            ordered.append(value)
        }

        return ordered
    }
}

