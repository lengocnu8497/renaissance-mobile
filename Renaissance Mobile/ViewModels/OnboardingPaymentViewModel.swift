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

    func fetchPrices() async {
        isFetchingPrices = true
        defer { isFetchingPrices = false }

        await subscriptionStore.prepare()
        errorMessage = subscriptionStore.errorMessage
    }

    func purchaseSubscription(tier: SubscriptionTier) async -> SubscriptionPurchaseOutcome {
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
        return outcome
    }

    private func priceInfo(for tier: SubscriptionTier) -> OnboardingPriceInfo? {
        guard let product = subscriptionStore.product(for: tier) else { return nil }
        return OnboardingPriceInfo(productId: product.id, displayPrice: product.displayPrice)
    }
}
