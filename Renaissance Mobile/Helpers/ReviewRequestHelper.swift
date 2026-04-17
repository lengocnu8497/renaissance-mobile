//
//  ReviewRequestHelper.swift
//  Renaissance Mobile
//

import StoreKit
import UIKit

enum ReviewRequestOutcome: Equatable {
    case requested
    case unavailableInTestFlight
    case unavailableScene

    var userFacingMessage: String? {
        switch self {
        case .requested:
            return nil
        case .unavailableInTestFlight:
            return "Apple does not display the in-app rating sheet in TestFlight builds. This button will work in the App Store release."
        case .unavailableScene:
            return "Apple's rating sheet was not available right now. Please try again in a moment."
        }
    }
}

@MainActor
enum ReviewRequestHelper {
    static func requestWhenReady(
        initialDelayMilliseconds: UInt64 = 0,
        maxAttempts: Int = 6,
        retryDelayMilliseconds: UInt64 = 350
    ) async -> ReviewRequestOutcome {
        if isTestFlightBuild(
            receiptLastPathComponent: Bundle.main.appStoreReceiptURL?.lastPathComponent,
            hasEmbeddedMobileProvision: Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil,
            isDebugBuild: isDebugBuild,
            isSimulator: isRunningOnSimulator
        ) {
            return .unavailableInTestFlight
        }

        if initialDelayMilliseconds > 0 {
            try? await Task.sleep(for: .milliseconds(initialDelayMilliseconds))
        }

        for attempt in 0..<maxAttempts {
            if let scene = activeWindowScene() {
                AppStore.requestReview(in: scene)
                return .requested
            }

            guard attempt < maxAttempts - 1 else { break }
            try? await Task.sleep(for: .milliseconds(retryDelayMilliseconds))
        }

        return .unavailableScene
    }

    static func isTestFlightBuild(
        receiptLastPathComponent: String?,
        hasEmbeddedMobileProvision: Bool,
        isDebugBuild: Bool,
        isSimulator: Bool
    ) -> Bool {
        guard !isSimulator else { return false }
        guard !isDebugBuild else { return false }
        return receiptLastPathComponent == "sandboxReceipt" && !hasEmbeddedMobileProvision
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private static var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private static func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        if let keyWindowScene = scenes.first(where: { scene in
            scene.activationState == .foregroundActive
                && scene.windows.contains(where: \.isKeyWindow)
        }) {
            return keyWindowScene
        }

        return scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first(where: { $0.activationState == .foregroundInactive })
    }
}
