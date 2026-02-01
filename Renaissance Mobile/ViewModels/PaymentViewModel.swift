//
//  PaymentViewModel.swift
//  Renaissance Mobile
//
//  Created by Claude on 1/10/26.
//

import Foundation
import UIKit
import Supabase
import StripePaymentSheet

@MainActor
@Observable
class PaymentViewModel {
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?

    // Stripe Payment Sheet
    var paymentSheet: PaymentSheet?
    var paymentSheetResult: PaymentSheetResult?

    // Store payment details for backend confirmation
    private var currentAmountCents: Int = 0
    private var currentCurrency: String = "USD"

    // MARK: - Prepare Payment Sheet with IntentConfiguration

    /// Prepares the Payment Sheet using IntentConfiguration (modern approach)
    /// - Parameters:
    ///   - amountCents: Amount in cents (e.g., 5000 = $50.00)
    ///   - currency: Currency code (default: "USD")
    ///   - metadata: Optional metadata to attach to the payment
    /// - Returns: True if preparation was successful
    func preparePaymentSheet(
        amountCents: Int,
        currency: String = "USD",
        metadata: [String: String]? = nil
    ) -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Store payment details for backend confirmation
        self.currentAmountCents = amountCents
        self.currentCurrency = currency

        // Create IntentConfiguration with payment mode
        let intentConfig = PaymentSheet.IntentConfiguration(
            mode: .payment(amount: amountCents, currency: currency)
        ) { [weak self] confirmationToken in
            guard let self = self else {
                throw PaymentError.cancelled
            }
            // Handle the confirmation token by sending it to your backend
            return try await self.handleConfirmationToken(
                confirmationToken,
                amountCents: self.currentAmountCents,
                currency: self.currentCurrency,
                metadata: metadata
            )
        }

        // Configure Payment Sheet appearance and settings
        var configuration = PaymentSheet.Configuration()

        // Basic configuration
        configuration.merchantDisplayName = "Renaissance"
        configuration.allowsDelayedPaymentMethods = true

        // Return URL for redirect-based payment methods
        configuration.returnURL = "renaissance://payment-complete"

        // Appearance customization to match your app
        var appearance = PaymentSheet.Appearance()
        appearance.colors.primary = UIColor(red: 208/255, green: 187/255, blue: 149/255, alpha: 1.0) // Renaissance gold
        appearance.colors.background = UIColor(red: 247/255, green: 247/255, blue: 246/255, alpha: 1.0)
        appearance.colors.componentBackground = UIColor.white
        appearance.colors.componentBorder = UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1.0)
        appearance.colors.componentDivider = UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1.0)
        appearance.colors.text = UIColor(red: 51/255, green: 51/255, blue: 51/255, alpha: 1.0)
        appearance.colors.textSecondary = UIColor(red: 130/255, green: 130/255, blue: 130/255, alpha: 1.0)
        appearance.colors.placeholderText = UIColor(red: 160/255, green: 160/255, blue: 160/255, alpha: 1.0)
        appearance.cornerRadius = 16
        configuration.appearance = appearance

        // Billing address collection
        configuration.billingDetailsCollectionConfiguration.name = .always
        configuration.billingDetailsCollectionConfiguration.email = .always
        configuration.billingDetailsCollectionConfiguration.phone = .always
        configuration.billingDetailsCollectionConfiguration.address = .full

        // Set primary button label
        configuration.primaryButtonLabel = "Pay \(formatAmount(amountCents))"

        // Enable Apple Pay
        configuration.applePay = PaymentSheet.ApplePayConfiguration(
            merchantId: EnvironmentConfig.appleMerchantId,
            merchantCountryCode: "US"
        )

        // Initialize Payment Sheet with IntentConfiguration
        paymentSheet = PaymentSheet(
            intentConfiguration: intentConfig,
            configuration: configuration
        )

        return true
    }

    // MARK: - Handle Confirmation Token

    /// Handles the confirmation token by sending it to your backend
    /// This is called automatically by PaymentSheet after the user confirms payment
    private func handleConfirmationToken(
        _ confirmationToken: STPConfirmationToken,
        amountCents: Int,
        currency: String,
        metadata: [String: String]?
    ) async throws -> String {
        // Create request with confirmation token and payment details
        struct ConfirmPaymentRequest: Encodable {
            let confirmation_token: String
            let amount_cents: Int
            let currency: String
            let metadata: [String: String]
        }

        struct ConfirmPaymentResponse: Decodable {
            let payment_intent_id: String
            let client_secret: String
            let status: String
        }

        let requestBody = ConfirmPaymentRequest(
            confirmation_token: confirmationToken.stripeId,
            amount_cents: amountCents,
            currency: currency,
            metadata: metadata ?? [:]
        )

        do {
            // Call your Supabase Edge Function to confirm the payment
            let response: ConfirmPaymentResponse = try await supabase.functions
                .invoke(
                    "confirm-payment",
                    options: FunctionInvokeOptions(body: requestBody)
                )

            // Return the client secret, not the payment intent ID
            // The callback expects a client secret in format: "pi_xxx_secret_xxx"
            return response.client_secret
        } catch {
            print("Error confirming payment: \(error)")
            throw PaymentError.confirmationFailed(error.localizedDescription)
        }
    }

    // MARK: - Present Payment Sheet

    /// Presents the Payment Sheet to the user
    /// - Returns: The result of the payment attempt
    func presentPaymentSheet() async -> PaymentSheetResult {
        guard let paymentSheet = paymentSheet else {
            let error = NSError(
                domain: "PaymentViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Payment sheet not initialized"]
            )
            return .failed(error: error)
        }

        // Get the topmost view controller to present from
        guard let topViewController = UIApplication.shared.topViewController else {
            let error = NSError(
                domain: "PaymentViewModel",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "No view controller found to present from"]
            )
            return .failed(error: error)
        }

        return await withCheckedContinuation { continuation in
            // Use DispatchQueue to ensure we're on the main thread and give UI time to settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                paymentSheet.present(from: topViewController) { [weak self] result in
                    self?.paymentSheetResult = result
                    continuation.resume(returning: result)
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Formats an amount in cents to a dollar string
    private func formatAmount(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return String(format: "$%.2f", dollars)
    }
}

// MARK: - Payment Errors

enum PaymentError: LocalizedError {
    case cancelled
    case invalidResponse
    case confirmationFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Payment was cancelled"
        case .invalidResponse:
            return "Invalid response from server"
        case .confirmationFailed(let message):
            return "Payment confirmation failed: \(message)"
        }
    }
}

// MARK: - UIApplication Extension

extension UIApplication {
    var topViewController: UIViewController? {
        guard let windowScene = connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        return getTopViewController(from: rootViewController)
    }

    private func getTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return getTopViewController(from: presented)
        }
        if let navigationController = viewController as? UINavigationController {
            return navigationController.visibleViewController ?? navigationController
        }
        if let tabBarController = viewController as? UITabBarController {
            return tabBarController.selectedViewController ?? tabBarController
        }
        return viewController
    }
}
