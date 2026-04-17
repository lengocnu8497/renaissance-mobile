//
//  ReviewRequestHelperTests.swift
//  Renaissance MobileTests
//

import XCTest
@testable import Renaissance_Mobile

final class ReviewRequestHelperTests: XCTestCase {

    func testIsTestFlightBuild_detectsSandboxReceiptWithoutProvisioningProfile() {
        XCTAssertTrue(
            ReviewRequestHelper.isTestFlightBuild(
                receiptLastPathComponent: "sandboxReceipt",
                hasEmbeddedMobileProvision: false,
                isDebugBuild: false,
                isSimulator: false
            ),
            "A release-signed build with a sandbox receipt and no embedded provisioning profile should be treated as TestFlight."
        )
    }

    func testIsTestFlightBuild_ignoresDebugBuilds() {
        XCTAssertFalse(
            ReviewRequestHelper.isTestFlightBuild(
                receiptLastPathComponent: "sandboxReceipt",
                hasEmbeddedMobileProvision: false,
                isDebugBuild: true,
                isSimulator: false
            ),
            "Local debug builds should still be allowed to exercise StoreKit's development review UI."
        )
    }

    func testIsTestFlightBuild_ignoresProductionReceipt() {
        XCTAssertFalse(
            ReviewRequestHelper.isTestFlightBuild(
                receiptLastPathComponent: "receipt",
                hasEmbeddedMobileProvision: false,
                isDebugBuild: false,
                isSimulator: false
            ),
            "App Store builds with a production receipt should not be mistaken for TestFlight."
        )
    }
}
