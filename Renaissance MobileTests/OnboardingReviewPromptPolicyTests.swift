//
//  OnboardingReviewPromptPolicyTests.swift
//  Renaissance MobileTests
//

import XCTest
@testable import Renaissance_Mobile

final class OnboardingReviewPromptPolicyTests: XCTestCase {

    func testShouldQueuePrompt_allowsFirstPromptInSession() {
        XCTAssertTrue(
            OnboardingReviewPromptPolicy.shouldQueuePrompt(hasQueuedPromptInSession: false),
            "The recovery-plan onboarding rating prompt should be eligible the first time the teaser becomes ready in a session."
        )
    }

    func testShouldQueuePrompt_blocksDuplicatePromptInSameSession() {
        XCTAssertFalse(
            OnboardingReviewPromptPolicy.shouldQueuePrompt(hasQueuedPromptInSession: true),
            "The recovery-plan onboarding rating prompt should not re-queue repeatedly within the same onboarding session."
        )
    }
}
