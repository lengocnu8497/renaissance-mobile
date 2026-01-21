//
//  SubscriptionViewModel.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/21/25.
//

import Foundation
import Supabase

struct CreateSubscriptionResult {
    let clientSecret: String
    let subscriptionId: String
}

struct CancelSubscriptionResult {
    let success: Bool
    let periodEndDate: Date?
}

@MainActor
@Observable
class SubscriptionViewModel {
    var subscription: SubscriptionModel?
    var transactions: [TransactionModel] = []
    var isLoading = false
    var errorMessage: String?
    var lastCreatedSubscriptionId: String?

    // MARK: - Fetch Current Subscription

    func fetchSubscription() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            guard let userId = supabase.auth.currentUser?.id.uuidString else {
                errorMessage = "User not authenticated"
                return
            }

            let response: SubscriptionModel = try await supabase.database
                .from("user_profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            subscription = response
        } catch {
            errorMessage = error.localizedDescription
            print("Fetch subscription error: \(error)")
        }
    }

    // MARK: - Fetch Transactions

    func fetchTransactions() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            guard let userId = supabase.auth.currentUser?.id.uuidString else {
                errorMessage = "User not authenticated"
                return
            }

            let response: [TransactionModel] = try await supabase.database
                .from("transactions")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            transactions = response
        } catch {
            errorMessage = error.localizedDescription
            print("Fetch transactions error: \(error)")
        }
    }

    // MARK: - Create Subscription

    func createSubscription(priceId: String, tier: SubscriptionTier) async -> CreateSubscriptionResult? {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Ensure we have a valid session
            let session = try await supabase.auth.session
            print("📱 Active session for user: \(session.user.id)")
            print("📱 Access token present: \(session.accessToken.prefix(20))...")

            struct CreateSubscriptionRequest: Encodable {
                let priceId: String
                let tier: String
            }

            struct CreateSubscriptionResponse: Decodable {
                let clientSecret: String
                let subscriptionId: String
                let customerId: String
            }

            let requestBody = CreateSubscriptionRequest(
                priceId: priceId,
                tier: tier.rawValue
            )

            print("📱 Calling create-subscription edge function...")

            // Call the edge function - the SDK should automatically include auth headers
            let response: CreateSubscriptionResponse = try await supabase.functions.invoke(
                "create-subscription",
                options: FunctionInvokeOptions(
                    body: requestBody
                )
            )

            print("📱 Subscription created successfully, ID: \(response.subscriptionId)")
            lastCreatedSubscriptionId = response.subscriptionId
            return CreateSubscriptionResult(
                clientSecret: response.clientSecret,
                subscriptionId: response.subscriptionId
            )
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Create subscription error: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error description: \(error.localizedDescription)")

            return nil
        }
    }

    // MARK: - Cancel Subscription

    func cancelSubscription() async -> CancelSubscriptionResult {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let session = try await supabase.auth.session
            print("📱 Canceling subscription for user: \(session.user.id)")

            struct CancelSubscriptionResponse: Decodable {
                let success: Bool
                let cancelAtPeriodEnd: Bool
                let currentPeriodEnd: Int
            }

            let response: CancelSubscriptionResponse = try await supabase.functions.invoke(
                "cancel-subscription",
                options: FunctionInvokeOptions()
            )

            print("✅ Subscription canceled, will end at period end: \(response.cancelAtPeriodEnd)")

            // Convert Unix timestamp to Date
            let periodEndDate = Date(timeIntervalSince1970: TimeInterval(response.currentPeriodEnd))

            // Refresh subscription data
            await fetchSubscription()

            return CancelSubscriptionResult(success: response.success, periodEndDate: periodEndDate)
        } catch let error as FunctionsError {
            // Extract more details from the FunctionsError
            switch error {
            case .httpError(let code, let data):
                let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode"
                print("❌ Cancel subscription HTTP error \(code): \(responseBody)")
                errorMessage = "Server error: \(responseBody)"
            case .relayError:
                print("❌ Cancel subscription relay error")
                errorMessage = "Network relay error"
            }
            return CancelSubscriptionResult(success: false, periodEndDate: nil)
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Cancel subscription error: \(error)")
            return CancelSubscriptionResult(success: false, periodEndDate: nil)
        }
    }
}
