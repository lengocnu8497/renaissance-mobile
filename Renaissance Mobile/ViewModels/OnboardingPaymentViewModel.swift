//
//  OnboardingPaymentViewModel.swift
//  Renaissance Mobile
//

import Foundation
import UIKit
import Supabase
import StripePaymentSheet

struct OnboardingPriceInfo {
    let priceId: String
    let displayPrice: String
    let unitAmount: Int
    let interval: String?
}

@MainActor
@Observable
class OnboardingPaymentViewModel {
    var isLoading = false
    var isFetchingPrices = false
    var errorMessage: String?

    // Fetched from Stripe — nil while loading
    var annualPriceInfo: OnboardingPriceInfo?
    var goldPriceInfo: OnboardingPriceInfo?
    var silverPriceInfo: OnboardingPriceInfo?

    // Set after a successful subscription creation — read by the view on .completed
    private(set) var lastCustomerId: String?
    private(set) var lastSubscriptionId: String?

    private var paymentSheet: PaymentSheet?

    // MARK: - Fetch Prices

    func fetchPrices() async {
        isFetchingPrices = true
        defer { isFetchingPrices = false }

        struct FetchRequest: Encodable {
            let priceIds: [String]
        }

        struct PriceResponse: Decodable {
            let priceId: String
            let unitAmount: Int
            let currency: String
            let interval: String?
            let displayPrice: String
        }

        do {
            let results: [PriceResponse] = try await supabase.functions.invoke(
                "fetch-stripe-prices",
                options: FunctionInvokeOptions(body: FetchRequest(priceIds: [
                    EnvironmentConfig.stripeAnnualPriceId,
                    EnvironmentConfig.stripeGoldPriceId,
                    EnvironmentConfig.stripeSilverPriceId,
                ]))
            )

            for item in results {
                let info = OnboardingPriceInfo(
                    priceId: item.priceId,
                    displayPrice: item.displayPrice,
                    unitAmount: item.unitAmount,
                    interval: item.interval
                )
                switch item.priceId {
                case EnvironmentConfig.stripeAnnualPriceId:  annualPriceInfo  = info
                case EnvironmentConfig.stripeGoldPriceId:    goldPriceInfo    = info
                case EnvironmentConfig.stripeSilverPriceId:  silverPriceInfo  = info
                default: break
                }
            }
        } catch {
            print("❌ Failed to fetch Stripe prices: \(error)")
        }
    }

    // MARK: - Prepare Subscription Payment Sheet

    func prepareSubscriptionPaymentSheet(email: String, priceId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            struct Request: Encodable {
                let email: String
                let priceId: String
            }

            struct Response: Decodable {
                let subscriptionId: String
                let clientSecret: String
                let customerId: String
                let unitAmount: Int
                let currency: String
                let interval: String
            }

            let response: Response = try await supabase.functions.invoke(
                "create-onboarding-subscription",
                options: FunctionInvokeOptions(body: Request(email: email, priceId: priceId))
            )

            // Store for linking after auth
            lastCustomerId = response.customerId
            lastSubscriptionId = response.subscriptionId

            // Configure PaymentSheet — mirrors PaymentViewModel style
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Rena"
            configuration.returnURL = "renaissance://payment-complete"
            configuration.allowsDelayedPaymentMethods = true

            // Pre-fill collected email so user doesn't re-enter it
            var billingDetails = PaymentSheet.BillingDetails()
            billingDetails.email = email
            configuration.defaultBillingDetails = billingDetails
            configuration.billingDetailsCollectionConfiguration.email = .never
            configuration.billingDetailsCollectionConfiguration.name = .always

            // Appearance to match app brand
            var appearance = PaymentSheet.Appearance()
            appearance.colors.primary = UIColor(red: 142/255, green: 76/255, blue: 92/255, alpha: 1.0)
            appearance.colors.background = UIColor(red: 255/255, green: 248/255, blue: 246/255, alpha: 1.0)
            appearance.colors.componentBackground = UIColor.white
            appearance.colors.componentBorder = UIColor(red: 196/255, green: 146/255, blue: 154/255, alpha: 0.6)
            appearance.colors.componentDivider = UIColor(red: 196/255, green: 146/255, blue: 154/255, alpha: 0.3)
            appearance.colors.text = UIColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1.0)
            appearance.colors.textSecondary = UIColor(red: 80/255, green: 80/255, blue: 80/255, alpha: 1.0)
            appearance.cornerRadius = 14
            configuration.appearance = appearance

            configuration.applePay = PaymentSheet.ApplePayConfiguration(
                merchantId: EnvironmentConfig.appleMerchantId,
                merchantCountryCode: "US"
            )

            paymentSheet = PaymentSheet(
                paymentIntentClientSecret: response.clientSecret,
                configuration: configuration
            )

            return true
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Onboarding subscription error: \(error)")
            return false
        }
    }

    // MARK: - Present Payment Sheet

    func presentPaymentSheet() async -> PaymentSheetResult {
        guard let paymentSheet else {
            return .failed(error: NSError(
                domain: "OnboardingPayment",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Payment not initialized"]
            ))
        }

        guard let topViewController = UIApplication.shared.topViewController else {
            return .failed(error: NSError(
                domain: "OnboardingPayment",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "No view controller found"]
            ))
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                paymentSheet.present(from: topViewController) { result in
                    continuation.resume(returning: result)
                }
            }
        }
    }
}
