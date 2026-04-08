//
//  RecoveryPlanGeneratedCopyValidatorTests.swift
//  Renaissance MobileTests
//

import XCTest
@testable import Renaissance_Mobile

final class RecoveryPlanGeneratedCopyValidatorTests: XCTestCase {

    func testValidate_acceptsWellFormedCopy() throws {
        let copy = RecoveryPlanGeneratedCopy.stub()
        let validated = try RecoveryPlanGeneratedCopyValidator.validate(
            copy,
            input: .stub(),
            timelinePhase: .stub()
        )

        XCTAssertEqual(validated.summary, copy.summary)
        XCTAssertEqual(validated.focusAreas.count, 2)
    }

    func testValidate_rejectsEmptySummary() {
        let copy = RecoveryPlanGeneratedCopy.stub(summary: "   ")

        XCTAssertThrowsError(
            try RecoveryPlanGeneratedCopyValidator.validate(
                copy,
                input: .stub(),
                timelinePhase: .stub()
            )
        )
    }

    func testValidate_rejectsTooManyFocusAreas() {
        let copy = RecoveryPlanGeneratedCopy.stub(
            focusAreas: [
                "One", "Two", "Three", "Four", "Five"
            ]
        )

        XCTAssertThrowsError(
            try RecoveryPlanGeneratedCopyValidator.validate(
                copy,
                input: .stub(),
                timelinePhase: .stub()
            )
        )
    }

    func testValidate_rejectsDiagnosticLanguage() {
        let copy = RecoveryPlanGeneratedCopy.stub(
            summary: "You have an infection and this confirms it."
        )

        XCTAssertThrowsError(
            try RecoveryPlanGeneratedCopyValidator.validate(
                copy,
                input: .stub(),
                timelinePhase: .stub()
            )
        )
    }

    func testValidate_rejectsEarlyPhaseContradictionForLaterWeek() {
        let copy = RecoveryPlanGeneratedCopy.stub(
            summary: "Right after surgery and during day 1, your focus should stay on immediate protection."
        )

        XCTAssertThrowsError(
            try RecoveryPlanGeneratedCopyValidator.validate(
                copy,
                input: .stub(currentWeek: 6),
                timelinePhase: .stub(status: .current)
            )
        )
    }

    func testSanitize_dedupesFocusAreasAndCollapsesWhitespace() {
        let copy = RecoveryPlanGeneratedCopy(
            summary: "  Weekly   comparisons   matter more now.  ",
            focusAreas: [
                "  Stay consistent with photos. ",
                "Stay consistent with photos.",
                " Track persistent changes. "
            ]
        )

        let sanitized = RecoveryPlanGeneratedCopyValidator.sanitize(copy)

        XCTAssertEqual(sanitized.summary, "Weekly comparisons matter more now.")
        XCTAssertEqual(
            sanitized.focusAreas,
            [
                "Stay consistent with photos.",
                "Track persistent changes."
            ]
        )
    }
}

