import XCTest
@testable import Renaissance_Mobile

final class OnboardingStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        OnboardingStore.reset()
    }

    override func tearDown() {
        OnboardingStore.reset()
        super.tearDown()
    }

    func testMaybeLaterCompletionSuppressesOnboarding() {
        XCTAssertTrue(OnboardingStore.shouldPresentOnboarding)
        XCTAssertEqual(OnboardingStore.presentationStatus, .pending)

        OnboardingStore.completeOnboarding(reason: .maybeLater, source: "test")

        XCTAssertFalse(OnboardingStore.shouldPresentOnboarding)
        XCTAssertTrue(OnboardingStore.hasCompleted)
        XCTAssertEqual(OnboardingStore.presentationStatus, .completed)
        XCTAssertEqual(OnboardingStore.completionReason, .maybeLater)
    }

    func testPurchasedCompletionSuppressesOnboarding() {
        OnboardingStore.completeOnboarding(reason: .purchased, source: "test")

        XCTAssertFalse(OnboardingStore.shouldPresentOnboarding)
        XCTAssertTrue(OnboardingStore.hasCompleted)
        XCTAssertEqual(OnboardingStore.presentationStatus, .completed)
        XCTAssertEqual(OnboardingStore.completionReason, .purchased)
    }

    func testResetClearsCompletionState() {
        OnboardingStore.completeOnboarding(reason: .maybeLater, source: "test")

        OnboardingStore.reset()

        XCTAssertTrue(OnboardingStore.shouldPresentOnboarding)
        XCTAssertFalse(OnboardingStore.hasCompleted)
        XCTAssertEqual(OnboardingStore.presentationStatus, .pending)
        XCTAssertNil(OnboardingStore.completionReason)
    }

    func testLegacyCompletedFlagStillSuppressesOnboarding() {
        UserDefaults.standard.set(true, forKey: "rena_onboarding_completed")

        XCTAssertTrue(OnboardingStore.hasCompleted)
        XCTAssertFalse(OnboardingStore.shouldPresentOnboarding)
        XCTAssertEqual(OnboardingStore.presentationStatus, .completed)
    }
}
