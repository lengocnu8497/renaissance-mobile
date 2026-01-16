//
//  SubscriptionViewModel.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/21/25.
//

import Foundation
import Supabase

@MainActor
@Observable
class SubscriptionViewModel {
    var subscription: SubscriptionModel?
    var transactions: [TransactionModel] = []
    var isLoading = false
    var errorMessage: String?

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

    func createSubscription(priceId: String, tier: SubscriptionTier) async -> String? {
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

            print("📱 Subscription created successfully")
            return response.clientSecret
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Create subscription error: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error description: \(error.localizedDescription)")

            return nil
        }
    }
}
