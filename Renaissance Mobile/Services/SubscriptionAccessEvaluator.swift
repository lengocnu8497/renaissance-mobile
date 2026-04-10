//
//  SubscriptionAccessEvaluator.swift
//  Renaissance Mobile
//

import Foundation

enum SubscriptionAccessEvaluator {
    static func hasBackendPremiumAccess(_ profile: UserProfile?, now: Date = Date()) -> Bool {
        guard let profile else { return false }
        guard profile.billingPlan != .free else { return false }

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
}
