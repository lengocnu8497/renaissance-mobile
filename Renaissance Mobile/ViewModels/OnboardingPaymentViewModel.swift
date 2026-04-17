//
//  OnboardingPaymentViewModel.swift
//  Renaissance Mobile
//

import Foundation
import StoreKit

struct OnboardingPriceInfo {
    let productId: String
    let displayPrice: String
}

@MainActor
@Observable
class OnboardingPaymentViewModel {
    var isLoading = false
    var isFetchingPrices = false
    var errorMessage: String?

    private let subscriptionStore: SubscriptionStore

    init(subscriptionStore: SubscriptionStore? = nil) {
        self.subscriptionStore = subscriptionStore ?? SubscriptionStore.shared
    }

    var yearlyPriceInfo: OnboardingPriceInfo? { priceInfo(for: .yearly) }
    var monthlyPriceInfo: OnboardingPriceInfo? { priceInfo(for: .monthly) }
    var weeklyPriceInfo: OnboardingPriceInfo? { priceInfo(for: .weekly) }
    var yearlyPlanPriceInfo: OnboardingPriceInfo? { yearlyPriceInfo }

    func isPlanAvailable(_ tier: SubscriptionTier) -> Bool {
        subscriptionStore.hasLoadedProduct(for: tier)
    }

    var isLoadingPlans: Bool {
        isFetchingPrices || subscriptionStore.isLoadingProducts
    }

    var hasAnyAvailablePlan: Bool {
        isPlanAvailable(.yearly) || isPlanAvailable(.monthly) || isPlanAvailable(.weekly)
    }

    func fetchPrices() async {
        logPaymentEvent(
            "payment.fetchPrices.started",
            details: [
                "hasActiveSubscription": String(subscriptionStore.hasActiveSubscription)
            ]
        )

        isFetchingPrices = true
        defer { isFetchingPrices = false }

        await subscriptionStore.prepare()
        errorMessage = subscriptionStore.errorMessage

        logPaymentEvent(
            "payment.fetchPrices.finished",
            details: [
                "hasAnyAvailablePlan": String(hasAnyAvailablePlan),
                "errorMessage": errorMessage
            ]
        )
    }

    func purchaseSubscription(tier: SubscriptionTier) async -> SubscriptionPurchaseOutcome {
        logPaymentEvent(
            "payment.purchase.started",
            details: [
                "tier": tier.rawValue,
                "hasActiveSubscription": String(subscriptionStore.hasActiveSubscription)
            ]
        )

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let outcome = await subscriptionStore.purchase(tier)
        if case .failed(let message) = outcome {
            errorMessage = message
        }
        if case .pending = outcome {
            errorMessage = "Your App Store purchase is pending approval."
        }

        logPaymentEvent(
            "payment.purchase.finished",
            details: [
                "tier": tier.rawValue,
                "outcome": String(describing: outcome),
                "hasActiveSubscription": String(subscriptionStore.hasActiveSubscription),
                "errorMessage": errorMessage
            ]
        )

        return outcome
    }

    private func priceInfo(for tier: SubscriptionTier) -> OnboardingPriceInfo? {
        guard let product = subscriptionStore.product(for: tier) else { return nil }
        return OnboardingPriceInfo(productId: product.id, displayPrice: product.displayPrice)
    }

    private func logPaymentEvent(_ event: String, details: [String: String?] = [:]) {
        let payload = details
            .compactMap { key, value -> String? in
                guard let value else { return nil }
                return "\(key)=\(value)"
            }
            .sorted()
            .joined(separator: " ")

        if payload.isEmpty {
            print("[OnboardingPayment] \(event)")
        } else {
            print("[OnboardingPayment] \(event) \(payload)")
        }
    }
}
