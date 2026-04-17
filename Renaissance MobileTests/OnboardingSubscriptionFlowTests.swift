//
//  OnboardingSubscriptionFlowTests.swift
//  Renaissance MobileTests
//

import XCTest
@testable import Renaissance_Mobile

final class OnboardingSubscriptionFlowTests: XCTestCase {

    func testFreshActiveEntitlement_isPreservedDuringTransientRefreshGap() async {
        let now = Date()
        let entitlement = SubscriptionEntitlement(
            tier: .yearly,
            productId: "renaissance.premium.yearly",
            transactionId: "txn_123",
            originalTransactionId: "orig_123",
            expirationDate: now.addingTimeInterval(86_400),
            status: .active,
            environment: .sandbox,
            signedTransactionInfo: "signed-jws"
        )

        let shouldPreserve = await MainActor.run {
            SubscriptionStore.shouldPreserveCurrentEntitlement(
                entitlement,
                updatedAt: now.addingTimeInterval(-5),
                now: now,
                graceInterval: 120
            )
        }

        XCTAssertTrue(
            shouldPreserve,
            "A just-purchased active entitlement should survive a brief refresh gap so onboarding can dismiss cleanly."
        )
    }

    func testStaleEntitlement_isNotPreservedForever() async {
        let now = Date()
        let entitlement = SubscriptionEntitlement(
            tier: .yearly,
            productId: "renaissance.premium.yearly",
            transactionId: "txn_456",
            originalTransactionId: "orig_456",
            expirationDate: now.addingTimeInterval(86_400),
            status: .active,
            environment: .sandbox,
            signedTransactionInfo: "signed-jws"
        )

        let shouldPreserve = await MainActor.run {
            SubscriptionStore.shouldPreserveCurrentEntitlement(
                entitlement,
                updatedAt: now.addingTimeInterval(-180),
                now: now,
                graceInterval: 120
            )
        }

        XCTAssertFalse(
            shouldPreserve,
            "The transient preservation window should expire so stale entitlements do not stick around indefinitely."
        )
    }

    func testExpiredCanceledEntitlement_isNotPreserved() async {
        let now = Date()
        let entitlement = SubscriptionEntitlement(
            tier: .monthly,
            productId: "renaissance.premium.monthly",
            transactionId: "txn_789",
            originalTransactionId: "orig_789",
            expirationDate: now.addingTimeInterval(-60),
            status: .canceled,
            environment: .sandbox,
            signedTransactionInfo: "signed-jws"
        )

        let shouldPreserve = await MainActor.run {
            SubscriptionStore.shouldPreserveCurrentEntitlement(
                entitlement,
                updatedAt: now.addingTimeInterval(-5),
                now: now,
                graceInterval: 120
            )
        }

        XCTAssertFalse(
            shouldPreserve,
            "An expired canceled entitlement must not keep onboarding or premium access alive."
        )
    }
}
