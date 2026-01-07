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
                .from("profiles")
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
            let requestBody: [String: Any] = [
                "priceId": priceId,
                "tier": tier.rawValue
            ]

            let response = try await supabase.functions.invoke(
                "create-subscription",
                options: FunctionInvokeOptions(
                    body: requestBody
                )
            )

            guard let data = response.data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let clientSecret = json["clientSecret"] as? String else {
                errorMessage = "Invalid response from server"
                return nil
            }

            return clientSecret
        } catch {
            errorMessage = error.localizedDescription
            print("Create subscription error: \(error)")
            return nil
        }
    }
}
