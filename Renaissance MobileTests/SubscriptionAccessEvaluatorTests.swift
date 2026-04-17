//
//  SubscriptionAccessEvaluatorTests.swift
//  Renaissance MobileTests
//

import XCTest
@testable import Renaissance_Mobile

final class SubscriptionAccessEvaluatorTests: XCTestCase {

    func testResolvedBackendTier_prefersSubscriptionTierOverLegacyBillingPlan() {
        let profile = UserProfile(
            billingPlan: .free,
            subscriptionTier: .yearly,
            subscriptionStatus: .active
        )

        XCTAssertEqual(
            SubscriptionAccessEvaluator.resolvedBackendTier(profile),
            .yearly
        )
    }

    func testHasBackendPremiumAccess_usesSubscriptionTierWhenBillingPlanIsStale() {
        let profile = UserProfile(
            billingPlan: .free,
            subscriptionTier: .monthly,
            subscriptionStatus: .active,
            subscriptionCurrentPeriodEnd: Date().addingTimeInterval(86_400)
        )

        XCTAssertTrue(
            SubscriptionAccessEvaluator.hasBackendPremiumAccess(profile)
        )
    }

    func testHasBackendPremiumAccess_rejectsCanceledTierOutsidePaidWindow() {
        let profile = UserProfile(
            billingPlan: .monthly,
            subscriptionTier: .monthly,
            subscriptionStatus: .canceled,
            subscriptionCurrentPeriodEnd: Date().addingTimeInterval(-60)
        )

        XCTAssertFalse(
            SubscriptionAccessEvaluator.hasBackendPremiumAccess(profile)
        )
    }

    func testResolvedState_usesSingleSnapshotForPaidProfileWhenLocalStoreIsEmpty() {
        let profile = UserProfile(
            billingPlan: .free,
            subscriptionTier: .monthly,
            subscriptionStatus: .active,
            subscriptionProvider: .appStore,
            subscriptionCurrentPeriodEnd: Date().addingTimeInterval(86_400)
        )

        let state = SubscriptionAccessEvaluator.resolvedState(
            profile,
            localTier: nil,
            localStatus: nil,
            localHasActiveSubscription: false
        )

        XCTAssertEqual(state.tier, .monthly)
        XCTAssertEqual(state.status, .active)
        XCTAssertTrue(state.hasPremiumAccess)
        XCTAssertEqual(state.planDisplayName, "Monthly")
        XCTAssertTrue(state.isAppStoreManaged)
    }

    func testResolvedState_reportsFreeWhenNoLocalOrBackendSubscriptionExists() {
        let profile = UserProfile(billingPlan: .free)

        let state = SubscriptionAccessEvaluator.resolvedState(
            profile,
            localTier: nil,
            localStatus: nil,
            localHasActiveSubscription: false
        )

        XCTAssertNil(state.tier)
        XCTAssertNil(state.status)
        XCTAssertFalse(state.hasPremiumAccess)
        XCTAssertEqual(state.planDisplayName, "Free")
        XCTAssertFalse(state.isAppStoreManaged)
    }
}
