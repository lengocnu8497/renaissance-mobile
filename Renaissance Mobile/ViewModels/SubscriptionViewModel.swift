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
    private var authTask: Task<Void, Never>?
    private var hasPrepared = false
    private var currentEntitlementUpdatedAt: Date?
    private var observedUserId: UUID?
    private let transientEntitlementGraceInterval: TimeInterval = 120
    private let backendSyncRetryDelaysNs: [UInt64] = [0, 700_000_000, 1_400_000_000]
    private let backendSyncVerificationPollDelayNs: UInt64 = 600_000_000
    private let backendSyncVerificationAttempts = 4
    private let profileService = UserProfileService(supabase: supabase)

    var activeTier: SubscriptionTier? {
        currentEntitlement?.tier
    }

    var subscriptionStatus: SubscriptionStatus? {
        currentEntitlement?.status
    }

    var hasActiveSubscription: Bool {
        currentEntitlement != nil
    }

    func hasLoadedProduct(for tier: SubscriptionTier) -> Bool {
        productsByTier[tier] != nil
    }

    func prepare() async {
        if !hasPrepared {
            hasPrepared = true
            observedUserId = supabase.auth.currentUser?.id
            startAuthStateListener()
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

        if productsByTier[tier] == nil {
            await loadProducts(forceRefresh: true)
            if productsByTier[tier] == nil {
                let message = productsByTier.isEmpty
                    ? "Subscription options are still loading. Please try again in a moment."
                    : "This subscription is not available right now."
                errorMessage = message
                return .failed(message)
            }
        }

        guard let product = productsByTier[tier] else {
            let message = "Subscription options are still loading. Please try again in a moment."
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

                if let entitlement = await makeEntitlement(
                    from: transaction,
                    signedTransactionInfo: verification.jwsRepresentation
                ) {
                    setCurrentEntitlement(entitlement)
                }

                await transaction.finish()
                let hasTrial = productsByTier[tier]?.subscription?.introductoryOffer?.paymentMode == .freeTrial
                if hasTrial {
                    Analytics.trialStarted(plan: tier.rawValue)
                } else {
                    Analytics.subscriptionStarted(plan: tier.rawValue)
                }
                _ = await ensurePremiumAccessIsSynced()
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

    /// Purchase the monthly plan with a StoreKit 2 promotional offer signature obtained from the backend.
    func purchaseWithPromoOffer(
        offerID: String,
        keyID: String,
        nonce: UUID,
        signature: Data,
        timestamp: Int
    ) async -> SubscriptionPurchaseOutcome {
        await loadProductsIfNeeded()

        guard let product = productsByTier[.monthly] else {
            let message = "Monthly subscription is not available right now."
            errorMessage = message
            return .failed(message)
        }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            var options = purchaseOptionsForCurrentUser()
            options.insert(.promotionalOffer(
                offerID: offerID,
                keyID: keyID,
                nonce: nonce,
                signature: signature,
                timestamp: timestamp
            ))
            let result = try await product.purchase(options: options)

            switch result {
            case .success(let verification):
                guard let transaction = verifiedTransaction(from: verification) else {
                    let message = "Unable to verify this App Store purchase."
                    errorMessage = message
                    return .failed(message)
                }
                if let entitlement = await makeEntitlement(
                    from: transaction,
                    signedTransactionInfo: verification.jwsRepresentation
                ) {
                    setCurrentEntitlement(entitlement)
                }
                await transaction.finish()
                Analytics.subscriptionStarted(plan: SubscriptionTier.monthly.rawValue)
                _ = await ensurePremiumAccessIsSynced()
                NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
                return .success
            case .pending:
                errorMessage = "Your purchase is pending approval."
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
        let previousEntitlement = currentEntitlement
        let refreshedEntitlement = await loadCurrentEntitlement()

        if let refreshedEntitlement {
            setCurrentEntitlement(refreshedEntitlement)
        } else if !shouldPreserveCurrentEntitlement(previousEntitlement) {
            setCurrentEntitlement(nil, shouldRefreshTimestamp: true)
        }

        if currentEntitlement != nil {
            _ = await ensurePremiumAccessIsSyncedAfterRefresh()
        } else {
            _ = await syncEntitlementIfNeeded()
        }
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

    private func startAuthStateListener() {
        guard authTask == nil else { return }

        authTask = Task { [weak self] in
            guard let self else { return }

            for await state in supabase.auth.authStateChanges {
                let nextUserId = state.session?.user.id
                guard nextUserId != self.observedUserId else { continue }

                self.observedUserId = nextUserId
                self.errorMessage = nil
                self.setCurrentEntitlement(nil, shouldRefreshTimestamp: true)
                NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
            }
        }
    }

    private func loadProductsIfNeeded() async {
        guard productsByTier.count != AppConfig.subscriptionProductIDs.count else { return }
        await loadProducts(forceRefresh: false)
    }

    private func loadProducts(forceRefresh: Bool) async {
        if isLoadingProducts {
            await waitForProductsLoadCompletion()
            return
        }

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

            if forceRefresh && productsByTier.isEmpty {
                errorMessage = "Subscription options are still loading. Please try again in a moment."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func waitForProductsLoadCompletion() async {
        while isLoadingProducts {
            await Task.yield()
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
            guard transactionBelongsToCurrentAppAccount(transaction) else { continue }
            guard let entitlement = await makeEntitlement(
                from: transaction,
                signedTransactionInfo: result.jwsRepresentation
            ) else {
                continue
            }

            if shouldReplaceCurrentEntitlement(latestEntitlement, with: entitlement) {
                latestEntitlement = entitlement
            }
        }

        return latestEntitlement
    }

    private func makeEntitlement(
        from transaction: Transaction,
        signedTransactionInfo: String
    ) async -> SubscriptionEntitlement? {
        guard let tier = AppConfig.tier(for: transaction.productID) else { return nil }
        guard transaction.revocationDate == nil else { return nil }

        let status = await resolveStatus(for: transaction)
        guard status == .active || status == .canceled || status == .pastDue else {
            return nil
        }

        return SubscriptionEntitlement(
            tier: tier,
            productId: transaction.productID,
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            expirationDate: transaction.expirationDate,
            status: status,
            environment: mapEnvironment(transaction.environment),
            signedTransactionInfo: signedTransactionInfo
        )
    }

    private func transactionBelongsToCurrentAppAccount(_ transaction: Transaction) -> Bool {
        guard let currentUserId = supabase.auth.currentUser?.id else {
            return true
        }

        guard let appAccountToken = transaction.appAccountToken else {
            // No account token on the transaction — accept it. This covers sandbox
            // purchases, restored transactions, and purchases made before account
            // tokens were introduced. We can't verify ownership, so we trust it.
            return true
        }

        return appAccountToken == currentUserId
    }

    private func setCurrentEntitlement(
        _ entitlement: SubscriptionEntitlement?,
        shouldRefreshTimestamp: Bool = true
    ) {
        currentEntitlement = entitlement

        guard shouldRefreshTimestamp else { return }
        currentEntitlementUpdatedAt = entitlement == nil ? nil : Date()
    }

    private func shouldPreserveCurrentEntitlement(
        _ entitlement: SubscriptionEntitlement?
    ) -> Bool {
        Self.shouldPreserveCurrentEntitlement(
            entitlement,
            updatedAt: currentEntitlementUpdatedAt,
            now: Date(),
            graceInterval: transientEntitlementGraceInterval
        )
    }

    static func shouldPreserveCurrentEntitlement(
        _ entitlement: SubscriptionEntitlement?,
        updatedAt: Date?,
        now: Date,
        graceInterval: TimeInterval
    ) -> Bool {
        guard let entitlement else { return false }
        guard let updatedAt else { return false }
        guard now.timeIntervalSince(updatedAt) <= graceInterval else { return false }

        switch entitlement.status {
        case .active, .pastDue:
            return true
        case .canceled:
            if let expirationDate = entitlement.expirationDate {
                return expirationDate > now
            }
            return false
        case .trialing, .incomplete, .incompleteExpired, .unpaid:
            return false
        }
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

    @discardableResult
    private func ensurePremiumAccessIsSyncedAfterRefresh() async -> Bool {
        let synced = await ensurePremiumAccessIsSynced()
        if !synced, currentEntitlement != nil {
            print("Subscription backend reconciliation is still pending after refresh.")
        }
        return synced
    }

    @discardableResult
    func ensurePremiumAccessIsSynced() async -> Bool {
        guard let entitlement = currentEntitlement else {
            return await syncEntitlementIfNeeded()
        }

        _ = await syncEntitlementIfNeededWithRetry()
        if await backendReflectsActiveEntitlement(expectedTier: entitlement.tier) {
            errorMessage = nil
            return true
        }

        for attempt in 0..<backendSyncVerificationAttempts {
            guard attempt < backendSyncVerificationAttempts - 1 else { break }
            try? await Task.sleep(nanoseconds: backendSyncVerificationPollDelayNs)
            _ = await syncEntitlementIfNeeded()

            if await backendReflectsActiveEntitlement(expectedTier: entitlement.tier) {
                errorMessage = nil
                return true
            }
        }

        return await backendReflectsActiveEntitlement(expectedTier: entitlement.tier)
    }

    private func backendReflectsActiveEntitlement(expectedTier: SubscriptionTier) async -> Bool {
        do {
            let profile = try await profileService.getUserProfile()
            guard SubscriptionAccessEvaluator.hasBackendPremiumAccess(profile) else { return false }
            return SubscriptionAccessEvaluator.resolvedBackendTier(profile) == expectedTier
        } catch {
            return false
        }
    }

    @discardableResult
    private func syncEntitlementIfNeededWithRetry() async -> Bool {
        if currentEntitlement == nil {
            return await syncEntitlementIfNeeded()
        }

        var lastFailureMessage: String?

        for delay in backendSyncRetryDelaysNs {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }

            let didSync = await syncEntitlementIfNeeded()
            if didSync {
                return true
            }

            lastFailureMessage = errorMessage
        }

        if let lastFailureMessage {
            errorMessage = lastFailureMessage
        }

        return false
    }

    @discardableResult
    private func syncEntitlementIfNeeded() async -> Bool {
        guard supabase.auth.currentUser != nil else { return false }

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
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
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

    func cancelSubscription(isAppStoreManaged: Bool = false) async -> CancelSubscriptionResult {
        errorMessage = nil

        if isAppStoreManaged {
            await subscriptionStore.prepare()

            let success = await subscriptionStore.presentManageSubscriptions()
            if !success {
                errorMessage = subscriptionStore.errorMessage
                    ?? "Unable to open the App Store subscription screen right now."
            }

            return CancelSubscriptionResult(
                success: success,
                periodEndDate: subscriptionStore.currentEntitlement?.expirationDate
            )
        }

        if subscriptionStore.hasActiveSubscription {
            let success = await subscriptionStore.presentManageSubscriptions()
            if !success {
                errorMessage = subscriptionStore.errorMessage
                    ?? "Unable to open the App Store subscription screen right now."
            }

            return CancelSubscriptionResult(
                success: success,
                periodEndDate: subscriptionStore.currentEntitlement?.expirationDate
            )
        }

        errorMessage = "No active App Store subscription was found on this device. Restore purchases first if your plan should still be active."
        return CancelSubscriptionResult(success: false, periodEndDate: nil)
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
