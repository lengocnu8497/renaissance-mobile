//
//  UsageTrackingService.swift
//  Renaissance Mobile
//
//  Service for managing usage tracking and quota limits
//

import Foundation
import Supabase

/// Service for managing usage tracking and quota limits
class UsageTrackingService {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - Fetch Current Usage

    /// Get current usage quota for the authenticated user
    func getCurrentUsage() async throws -> UsageQuota {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw UsageTrackingError.notAuthenticated
        }

        // Get user's subscription info first
        let profile: UserProfile = try await supabase.database
            .from("user_profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        // Check if user has active subscription (not free tier)
        // Only silver and gold plans can use AI chat
        guard profile.billingPlan == .silver || profile.billingPlan == .gold else {
            throw UsageTrackingError.noActiveSubscription
        }

        // Map BillingPlan to SubscriptionTier
        guard let tier = SubscriptionTier(rawValue: profile.billingPlan.rawValue) else {
            throw UsageTrackingError.noActiveSubscription
        }

        // Get current usage record for this billing period
        let response: [UsageQuota] = try await supabase.database
            .from("usage_tracking")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("period_end", ascending: false)
            .limit(1)
            .execute()
            .value

        if let currentUsage = response.first {
            return currentUsage
        } else {
            // No usage record exists yet - user hasn't sent any messages this period
            // Return a default quota with zero usage
            let limits = TierQuotaLimits.limits(for: tier)

            return UsageQuota(
                id: UUID(),
                userId: userId,
                periodStart: Date(),
                periodEnd: Date(),
                messagesUsed: 0,
                imagesUsed: 0,
                creditsUsed: 0,
                messagesLimit: limits.messagesLimit,
                imagesLimit: limits.imagesLimit,
                creditsLimit: limits.creditsLimit,
                subscriptionTier: tier,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
    }

    // MARK: - Check if Message Can Be Sent

    /// Check if user can send a message without exceeding quota
    func canSendMessage(hasImage: Bool) async throws -> (canSend: Bool, reason: String?) {
        // Try to get current usage - if user has no active subscription, catch it here
        let usage: UsageQuota
        do {
            usage = try await getCurrentUsage()
        } catch UsageTrackingError.noActiveSubscription {
            // User doesn't have an active subscription - return false with subscription message
            return (false, UsageTrackingError.noActiveSubscription.errorDescription)
        } catch {
            // Other errors (network, database, etc.) should be thrown up to the caller
            throw error
        }

        let messageCost = 1
        let imageCost = hasImage ? 1 : 0
        let creditCost = hasImage ? 4 : 2

        let wouldExceedMessages = (usage.messagesUsed + messageCost) > usage.messagesLimit
        let wouldExceedImages = hasImage && (usage.imagesUsed + imageCost) > usage.imagesLimit
        let wouldExceedCredits = (usage.creditsUsed + creditCost) > usage.creditsLimit

        if wouldExceedMessages {
            return (false, "You've reached your monthly message limit (\(usage.messagesLimit) messages)")
        }

        if wouldExceedImages {
            return (false, "You've reached your monthly image analysis limit (\(usage.imagesLimit) images)")
        }

        if wouldExceedCredits {
            return (false, "You've reached your monthly AI credit limit (\(usage.creditsLimit) credits)")
        }

        return (true, nil)
    }
}

// MARK: - Errors

enum UsageTrackingError: LocalizedError {
    case notAuthenticated
    case noActiveSubscription
    case quotaExceeded(limitType: String)
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .noActiveSubscription:
            return "Subscribe to unlock AI chat and get personalized beauty recommendations"
        case .quotaExceeded(let limitType):
            return "You've exceeded your \(limitType) quota for this billing period"
        case .fetchFailed:
            return "Failed to fetch usage data"
        }
    }
}
