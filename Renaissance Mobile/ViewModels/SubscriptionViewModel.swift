//
//  SubscriptionViewModel.swift
//  Renaissance Mobile
//
//  StoreKit-backed subscription state and a thin view-model wrapper for
//  settings/transaction history surfaces.
//

import Foundation
import StoreKit
import UIKit
import Supabase

enum SubscriptionPurchaseOutcome: Equatable {
    case success
    case pending
    case cancelled
    case failed(String)
}

struct CancelSubscriptionResult {
    let success: Bool
    let periodEndDate: Date?
}

struct SubscriptionEntitlement: Equatable {
    let tier: SubscriptionTier
    let productId: String
    let transactionId: String
    let originalTransactionId: String
    let expirationDate: Date?
    let status: SubscriptionStatus
    let environment: AppStoreEnvironment
    let signedTransactionInfo: String
}

@MainActor
@Observable
final class SubscriptionStore {
    static let shared = SubscriptionStore()

    private(set) var productsByTier: [SubscriptionTier: Product] = [:]
    private(set) var currentEntitlement: SubscriptionEntitlement?
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    var errorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var hasPrepared = false

    var activeTier: SubscriptionTier? {
        currentEntitlement?.tier
    }

    var subscriptionStatus: SubscriptionStatus? {
        currentEntitlement?.status
    }

    var hasActiveSubscription: Bool {
        currentEntitlement != nil
    }

    func prepare() async {
        if !hasPrepared {
            hasPrepared = true
            startTransactionListener()
        }

        await loadProductsIfNeeded()
        await refreshEntitlementsAndSync()
    }

    func product(for tier: SubscriptionTier) -> Product? {
        productsByTier[tier]
    }

    func displayPrice(for tier: SubscriptionTier) -> String {
        productsByTier[tier]?.displayPrice ?? "..."
    }

    func purchase(_ tier: SubscriptionTier) async -> SubscriptionPurchaseOutcome {
        await loadProductsIfNeeded()

        guard let product = productsByTier[tier] else {
            let message = "This subscription is not available right now."
            errorMessage = message
            return .failed(message)
        }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let purchaseOptions = purchaseOptionsForCurrentUser()
            let result = try await product.purchase(options: purchaseOptions)

            switch result {
            case .success(let verification):
                guard let transaction = verifiedTransaction(from: verification) else {
                    let message = "Unable to verify this App Store purchase."
                    errorMessage = message
                    return .failed(message)
                }

                await transaction.finish()
                await refreshEntitlementsAndSync()
                NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
                return .success

            case .pending:
                let message = "Your purchase is pending approval."
                errorMessage = message
                return .pending

            case .userCancelled:
                return .cancelled

            @unknown default:
                let message = "The App Store returned an unexpected purchase state."
                errorMessage = message
                return .failed(message)
            }
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            return .failed(message)
        }
    }

    func restorePurchases() async -> Bool {
        do {
            try await AppStore.sync()
            await refreshEntitlementsAndSync()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshEntitlementsAndSync() async {
        currentEntitlement = await loadCurrentEntitlement()
        await syncEntitlementIfNeeded()
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }

    func presentManageSubscriptions() async -> Bool {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            errorMessage = "Unable to open the App Store subscription screen."
            return false
        }

        do {
            try await AppStore.showManageSubscriptions(in: scene)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func startTransactionListener() {
        guard updatesTask == nil else { return }

        updatesTask = Task { [weak self] in
            guard let self else { return }

            for await result in Transaction.updates {
                guard let transaction = self.verifiedTransaction(from: result) else {
                    continue
                }

                await transaction.finish()
                await self.refreshEntitlementsAndSync()
            }
        }
    }

    private func loadProductsIfNeeded() async {
        guard productsByTier.count != AppConfig.subscriptionProductIDs.count else { return }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: AppConfig.subscriptionProductIDs)
            productsByTier = Dictionary(
                uniqueKeysWithValues: products.compactMap { product in
                    guard let tier = AppConfig.tier(for: product.id) else { return nil }
                    return (tier, product)
                }
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func purchaseOptionsForCurrentUser() -> Set<Product.PurchaseOption> {
        guard let userId = supabase.auth.currentUser?.id else {
            return []
        }

        return [.appAccountToken(userId)]
    }

    private func loadCurrentEntitlement() async -> SubscriptionEntitlement? {
        var latestEntitlement: SubscriptionEntitlement?

        for await result in Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: result) else { continue }
            guard let tier = AppConfig.tier(for: transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }

            let status = await resolveStatus(for: transaction)
            guard status == .active || status == .canceled || status == .pastDue else {
                continue
            }

            let entitlement = SubscriptionEntitlement(
                tier: tier,
                productId: transaction.productID,
                transactionId: String(transaction.id),
                originalTransactionId: String(transaction.originalID),
                expirationDate: transaction.expirationDate,
                status: status,
                environment: mapEnvironment(transaction.environment),
                signedTransactionInfo: result.jwsRepresentation
            )

            if shouldReplaceCurrentEntitlement(latestEntitlement, with: entitlement) {
                latestEntitlement = entitlement
            }
        }

        return latestEntitlement
    }

    private func shouldReplaceCurrentEntitlement(
        _ current: SubscriptionEntitlement?,
        with candidate: SubscriptionEntitlement
    ) -> Bool {
        guard let current else { return true }

        switch (current.expirationDate, candidate.expirationDate) {
        case let (.some(currentDate), .some(candidateDate)):
            return candidateDate > currentDate
        case (.none, .some):
            return true
        case (.some, .none):
            return false
        case (.none, .none):
            return candidate.transactionId > current.transactionId
        }
    }

    private func resolveStatus(for transaction: Transaction) async -> SubscriptionStatus {
        guard let subscriptionStatus = await transaction.subscriptionStatus else {
            if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                return .canceled
            }
            return .active
        }

        switch subscriptionStatus.state {
        case .subscribed:
            if case .verified(let renewalInfo) = subscriptionStatus.renewalInfo, !renewalInfo.willAutoRenew {
                return .canceled
            }
            return .active
        case .inGracePeriod, .inBillingRetryPeriod:
            return .pastDue
        case .expired, .revoked:
            return .canceled
        default:
            return .active
        }
    }

    private func mapEnvironment(_ environment: AppStore.Environment) -> AppStoreEnvironment {
        if environment == .sandbox {
            return .sandbox
        }
        if environment == .xcode {
            return .xcode
        }
        return .production
    }

    private func verifiedTransaction(
        from result: VerificationResult<Transaction>
    ) -> Transaction? {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified(_, let error):
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func syncEntitlementIfNeeded() async {
        guard supabase.auth.currentUser != nil else { return }

        struct SyncRequest: Encodable {
            let isActive: Bool
            let tier: String?
            let status: String?
            let productId: String?
            let transactionId: String?
            let originalTransactionId: String?
            let expirationDate: String?
            let environment: String?
            let signedTransactionInfo: String?
        }

        struct SyncResponse: Decodable {
            let success: Bool
        }

        let isoFormatter = ISO8601DateFormatter()
        let entitlement = currentEntitlement

        do {
            let _: SyncResponse = try await supabase.functions.invoke(
                "sync-subscription-status",
                options: FunctionInvokeOptions(
                    body: SyncRequest(
                        isActive: entitlement != nil,
                        tier: entitlement?.tier.rawValue,
                        status: entitlement?.status.rawValue,
                        productId: entitlement?.productId,
                        transactionId: entitlement?.transactionId,
                        originalTransactionId: entitlement?.originalTransactionId,
                        expirationDate: entitlement?.expirationDate.map(isoFormatter.string(from:)),
                        environment: entitlement?.environment.rawValue,
                        signedTransactionInfo: entitlement?.signedTransactionInfo
                    )
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
@Observable
class SubscriptionViewModel {
    var subscription: SubscriptionModel?
    var transactions: [TransactionModel] = []
    var isLoading = false
    var errorMessage: String?

    private let subscriptionStore = SubscriptionStore.shared

    var activeTier: SubscriptionTier? {
        subscriptionStore.activeTier
    }

    var activeStatus: SubscriptionStatus? {
        subscriptionStore.subscriptionStatus
    }

    var hasActiveSubscription: Bool {
        subscriptionStore.hasActiveSubscription
    }

    func fetchSubscription() async {
        await subscriptionStore.prepare()

        if let entitlement = subscriptionStore.currentEntitlement {
            subscription = SubscriptionModel(
                id: entitlement.originalTransactionId,
                status: entitlement.status,
                tier: entitlement.tier,
                currentPeriodEnd: entitlement.expirationDate,
                provider: .appStore,
                productId: entitlement.productId,
                originalTransactionId: entitlement.originalTransactionId
            )
        } else {
            subscription = nil
        }
    }

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
        }
    }

    func cancelSubscription() async -> CancelSubscriptionResult {
        if subscriptionStore.hasActiveSubscription {
            let success = await subscriptionStore.presentManageSubscriptions()
            return CancelSubscriptionResult(
                success: success,
                periodEndDate: subscriptionStore.currentEntitlement?.expirationDate
            )
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            struct CancelSubscriptionResponse: Decodable {
                let success: Bool
                let currentPeriodEnd: Int
            }

            let response: CancelSubscriptionResponse = try await supabase.functions.invoke(
                "cancel-subscription",
                options: FunctionInvokeOptions()
            )

            return CancelSubscriptionResult(
                success: response.success,
                periodEndDate: Date(timeIntervalSince1970: TimeInterval(response.currentPeriodEnd))
            )
        } catch let error as FunctionsError {
            switch error {
            case .httpError(_, let data):
                errorMessage = String(data: data, encoding: .utf8) ?? "Server error"
            case .relayError:
                errorMessage = "Network relay error"
            }
            return CancelSubscriptionResult(success: false, periodEndDate: nil)
        } catch {
            errorMessage = error.localizedDescription
            return CancelSubscriptionResult(success: false, periodEndDate: nil)
        }
    }
}

private extension SubscriptionModel {
    init(
        id: String?,
        status: SubscriptionStatus?,
        tier: SubscriptionTier?,
        currentPeriodEnd: Date?,
        provider: SubscriptionProvider?,
        productId: String?,
        originalTransactionId: String?
    ) {
        self.id = id
        self.status = status
        self.tier = tier
        self.currentPeriodEnd = currentPeriodEnd
        self.provider = provider
        self.productId = productId
        self.originalTransactionId = originalTransactionId
    }
}
