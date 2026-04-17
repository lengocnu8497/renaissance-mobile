//
//  SubscriptionAccessEvaluator.swift
//  Renaissance Mobile
//

import Foundation

enum SubscriptionAccessEvaluator {
    struct ResolvedSubscriptionState: Equatable {
        let tier: SubscriptionTier?
        let status: SubscriptionStatus?
        let hasPremiumAccess: Bool
        let planDisplayName: String
        let isAppStoreManaged: Bool
    }

    static func resolvedSubscriptionStatus(
        _ profile: UserProfile?,
        localStatus: SubscriptionStatus?
    ) -> SubscriptionStatus? {
        localStatus ?? profile?.subscriptionStatus
    }

    static func resolvedBackendTier(_ profile: UserProfile?) -> SubscriptionTier? {
        guard let profile else { return nil }

        if let subscriptionTier = profile.subscriptionTier {
            return subscriptionTier
        }

        return SubscriptionTier(rawValue: profile.billingPlan.rawValue)
    }

    static func resolvedTier(
        _ profile: UserProfile?,
        localTier: SubscriptionTier?
    ) -> SubscriptionTier? {
        localTier ?? resolvedBackendTier(profile)
    }

    static func hasBackendPremiumAccess(_ profile: UserProfile?, now: Date = Date()) -> Bool {
        guard let profile else { return false }
        guard resolvedBackendTier(profile) != nil else { return false }

        switch profile.subscriptionStatus {
        case .active, .trialing:
            return true
        case .canceled:
            guard let periodEnd = profile.subscriptionCurrentPeriodEnd else { return false }
            return periodEnd > now
        case .pastDue, .incomplete, .incompleteExpired, .unpaid, .none:
            return false
        }
    }

    static func hasResolvedPremiumAccess(
        _ profile: UserProfile?,
        localHasActiveSubscription: Bool,
        now: Date = Date()
    ) -> Bool {
        if localHasActiveSubscription {
            return true
        }

        return hasBackendPremiumAccess(profile, now: now)
    }

    static func resolvedPlanDisplayName(
        _ profile: UserProfile?,
        localTier: SubscriptionTier?,
        localStatus: SubscriptionStatus?
    ) -> String {
        if let tier = resolvedTier(profile, localTier: localTier) {
            return tier.displayName
        }

        if profile?.subscriptionProvider == .appStore,
           resolvedSubscriptionStatus(profile, localStatus: localStatus) == .active {
            return "Premium"
        }

        return "Free"
    }

    static func resolvedState(
        _ profile: UserProfile?,
        localTier: SubscriptionTier?,
        localStatus: SubscriptionStatus?,
        localHasActiveSubscription: Bool,
        now: Date = Date()
    ) -> ResolvedSubscriptionState {
        let tier = resolvedTier(profile, localTier: localTier)
        let status = resolvedSubscriptionStatus(profile, localStatus: localStatus)
        let hasPremiumAccess = hasResolvedPremiumAccess(
            profile,
            localHasActiveSubscription: localHasActiveSubscription,
            now: now
        )

        return ResolvedSubscriptionState(
            tier: tier,
            status: status,
            hasPremiumAccess: hasPremiumAccess,
            planDisplayName: resolvedPlanDisplayName(
                profile,
                localTier: localTier,
                localStatus: localStatus
            ),
            isAppStoreManaged: localHasActiveSubscription || profile?.subscriptionProvider == .appStore
        )
    }
}
