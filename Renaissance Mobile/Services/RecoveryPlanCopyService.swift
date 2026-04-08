//
//  RecoveryPlanCopyService.swift
//  Renaissance Mobile
//

import Foundation
import Supabase

private let _defaultRecoveryPlanCopySupabase: SupabaseClient = supabase

protocol RecoveryPlanCopyGenerating {
    func generateCopy(
        input: RecoveryPlanInput,
        timelinePhase: RecoveryPlanTimelinePhase,
        journalSignals: RecoveryPlanJournalSignals?
    ) async throws -> RecoveryPlanGeneratedCopy
}

enum RecoveryPlanCopyServiceError: LocalizedError {
    case serviceDisabled
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .serviceDisabled:
            return "AI recovery plan copy generation is currently disabled."
        case .invalidResponse:
            return "The AI recovery plan copy response was invalid."
        }
    }
}

struct RecoveryPlanCopyRequest: Encodable, Equatable {
    let systemInstructions: String
    let userPrompt: String
    let schemaVersion: String
    let input: RecoveryPlanInput
    let timelinePhase: RecoveryPlanTimelinePhase
    let journalSignals: RecoveryPlanJournalSignals?
}

private struct RecoveryPlanCopyResponse: Decodable {
    let summary: String
    let focusAreas: [String]
}

final class RecoveryPlanCopyService: RecoveryPlanCopyGenerating {
    private let supabase: SupabaseClient
    private let functionName: String

    init(
        supabase: SupabaseClient = _defaultRecoveryPlanCopySupabase,
        functionName: String = "generate-recovery-plan-copy"
    ) {
        self.supabase = supabase
        self.functionName = functionName
    }

    func generateCopy(
        input: RecoveryPlanInput,
        timelinePhase: RecoveryPlanTimelinePhase,
        journalSignals: RecoveryPlanJournalSignals?
    ) async throws -> RecoveryPlanGeneratedCopy {
        let promptPackage = RecoveryPlanCopyPromptBuilder.build(
            input: input,
            timelinePhase: timelinePhase,
            journalSignals: journalSignals
        )

        let request = RecoveryPlanCopyRequest(
            systemInstructions: promptPackage.systemInstructions,
            userPrompt: promptPackage.userPrompt,
            schemaVersion: promptPackage.schemaVersion,
            input: input,
            timelinePhase: timelinePhase,
            journalSignals: journalSignals
        )

        let response: RecoveryPlanCopyResponse = try await supabase.functions.invoke(
            functionName,
            options: FunctionInvokeOptions(body: request)
        )

        let generatedCopy = RecoveryPlanGeneratedCopy(
            summary: response.summary,
            focusAreas: response.focusAreas
        )

        do {
            return try RecoveryPlanGeneratedCopyValidator.validate(
                generatedCopy,
                input: input,
                timelinePhase: timelinePhase
            )
        } catch let error as RecoveryPlanGeneratedCopyValidationError {
            print("RecoveryPlanCopyService validation failed: \(error.localizedDescription)")
            throw RecoveryPlanCopyServiceError.invalidResponse
        }
    }
}

struct DisabledRecoveryPlanCopyService: RecoveryPlanCopyGenerating {
    func generateCopy(
        input: RecoveryPlanInput,
        timelinePhase: RecoveryPlanTimelinePhase,
        journalSignals: RecoveryPlanJournalSignals?
    ) async throws -> RecoveryPlanGeneratedCopy {
        throw RecoveryPlanCopyServiceError.serviceDisabled
    }
}
