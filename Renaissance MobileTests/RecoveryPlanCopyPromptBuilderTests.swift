//
//  RecoveryPlanCopyPromptBuilderTests.swift
//  Renaissance MobileTests
//

import XCTest
@testable import Renaissance_Mobile

final class RecoveryPlanCopyPromptBuilderTests: XCTestCase {

    func testBuild_includesStructuredRecoveryContext() {
        let input = RecoveryPlanInput.stub(
            aestheticGoals: ["Symmetry", "Reduce swelling"],
            bodyAreas: ["Face"],
            previousProcedures: ["Fillers"],
            healthFlags: ["Sensitive healing"],
            latestJournalSignals: RecoveryPlanJournalSignals(
                entryCount: 4,
                latestPainLevel: 3,
                latestSwellingLevel: 4,
                latestBruisingLevel: 1,
                latestRednessLevel: 1,
                weeklySummaryHeadline: "Swelling is gradually improving.",
                activeAlerts: ["Persistent asymmetry noted"]
            )
        )

        let package = RecoveryPlanCopyPromptBuilder.build(
            input: input,
            timelinePhase: .stub(),
            journalSignals: input.latestJournalSignals
        )

        XCTAssertEqual(package.schemaVersion, "recovery_plan_copy_v1")
        XCTAssertTrue(package.systemInstructions.contains("Return valid JSON only."))
        XCTAssertTrue(package.userPrompt.contains("Procedure name: Rhinoplasty"))
        XCTAssertTrue(package.userPrompt.contains("Aesthetic goals: Symmetry, Reduce swelling"))
        XCTAssertTrue(package.userPrompt.contains("Previous procedures: Fillers"))
        XCTAssertTrue(package.userPrompt.contains("Health flags: Sensitive healing"))
        XCTAssertTrue(package.userPrompt.contains("Weekly summary headline: Swelling is gradually improving."))
        XCTAssertTrue(package.userPrompt.contains("Active alerts: Persistent asymmetry noted"))
    }

    func testBuild_usesNoneProvidedForMissingOptionalContext() {
        let input = RecoveryPlanInput.stub(
            gender: nil,
            ageRange: nil,
            raceEthnicity: nil,
            aestheticGoals: [],
            bodyAreas: [],
            previousProcedures: [],
            healthFlags: [],
            latestJournalSignals: nil
        )

        let package = RecoveryPlanCopyPromptBuilder.build(
            input: input,
            timelinePhase: .stub(),
            journalSignals: nil
        )

        XCTAssertTrue(package.userPrompt.contains("Aesthetic goals: None provided"))
        XCTAssertTrue(package.userPrompt.contains("Body areas: None provided"))
        XCTAssertTrue(package.userPrompt.contains("Previous procedures: None provided"))
        XCTAssertTrue(package.userPrompt.contains("Health flags: None provided"))
        XCTAssertTrue(package.userPrompt.contains("Gender: None provided"))
        XCTAssertTrue(package.userPrompt.contains("No journal signals available"))
    }
}

