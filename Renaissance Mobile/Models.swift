//
//  Models.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import Foundation
import UIKit

// MARK: - Chat Conversation Model (Database)
struct ChatConversation: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    var title: String?
    let createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isArchived = "is_archived"
        case metadata
    }

    init(id: UUID = UUID(), userId: UUID, title: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), isArchived: Bool = false, metadata: [String: AnyCodable]? = nil) {
        self.id = id
        self.userId = userId
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.metadata = metadata
    }
}

// MARK: - Chat Message Model (Database)
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    var conversationId: UUID?
    var userId: UUID?
    let messageText: String
    let isFromUser: Bool
    let createdAt: Date
    var openaiResponseId: String?
    var openaiModel: String?
    var hasImage: Bool
    var imageUrl: String?
    var imageMetadata: [String: AnyCodable]?
    var tokensUsed: Int?
    var responseTimeMs: Int?
    var metadata: [String: AnyCodable]?

    // Transient property for local image data (not stored in DB)
    var imageData: Data?

    // Computed properties for backward compatibility with UI
    var text: String { messageText }
    var timestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: createdAt)
    }
    var responseId: String? { openaiResponseId }

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case messageText = "message_text"
        case isFromUser = "is_from_user"
        case createdAt = "created_at"
        case openaiResponseId = "openai_response_id"
        case openaiModel = "openai_model"
        case hasImage = "has_image"
        case imageUrl = "image_url"
        case imageMetadata = "image_metadata"
        case tokensUsed = "tokens_used"
        case responseTimeMs = "response_time_ms"
        case metadata
    }

    // Initializer for creating new messages
    init(
        id: UUID = UUID(),
        conversationId: UUID? = nil,
        userId: UUID? = nil,
        messageText: String,
        isFromUser: Bool,
        createdAt: Date = Date(),
        openaiResponseId: String? = nil,
        openaiModel: String? = nil,
        hasImage: Bool = false,
        imageUrl: String? = nil,
        imageMetadata: [String: AnyCodable]? = nil,
        tokensUsed: Int? = nil,
        responseTimeMs: Int? = nil,
        metadata: [String: AnyCodable]? = nil,
        imageData: Data? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.userId = userId
        self.messageText = messageText
        self.isFromUser = isFromUser
        self.createdAt = createdAt
        self.openaiResponseId = openaiResponseId
        self.openaiModel = openaiModel
        self.hasImage = hasImage
        self.imageUrl = imageUrl
        self.imageMetadata = imageMetadata
        self.tokensUsed = tokensUsed
        self.responseTimeMs = responseTimeMs
        self.metadata = metadata
        self.imageData = imageData
    }

    // Legacy initializer for backward compatibility
    init(text: String, isFromUser: Bool, timestamp: String, responseId: String?, imageData: Data? = nil) {
        self.id = UUID()
        self.conversationId = nil
        self.userId = nil
        self.messageText = text
        self.isFromUser = isFromUser
        self.createdAt = Date()
        self.openaiResponseId = responseId
        self.openaiModel = nil
        self.hasImage = imageData != nil
        self.imageUrl = nil
        self.imageMetadata = nil
        self.tokensUsed = nil
        self.responseTimeMs = nil
        self.metadata = nil
        self.imageData = imageData
    }
}

// MARK: - User Profile Model (Database)
struct UserProfile: Identifiable, Codable {
    let id: UUID
    var fullName: String?
    var email: String?
    var phoneNumber: String?
    var zipCode: String?
    var billingPlan: BillingPlan
    var profileImageUrl: String?
    var subscriptionStatus: SubscriptionStatus?
    var subscriptionCurrentPeriodEnd: Date?
    let createdAt: Date
    var updatedAt: Date
    var metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case phoneNumber = "phone_number"
        case zipCode = "zip_code"
        case billingPlan = "billing_plan"
        case profileImageUrl = "profile_image_url"
        case subscriptionStatus = "subscription_status"
        case subscriptionCurrentPeriodEnd = "subscription_current_period_end"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case metadata
    }

    init(
        id: UUID = UUID(),
        fullName: String? = nil,
        email: String? = nil,
        phoneNumber: String? = nil,
        zipCode: String? = nil,
        billingPlan: BillingPlan = .free,
        profileImageUrl: String? = nil,
        subscriptionStatus: SubscriptionStatus? = nil,
        subscriptionCurrentPeriodEnd: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadata: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phoneNumber = phoneNumber
        self.zipCode = zipCode
        self.billingPlan = billingPlan
        self.profileImageUrl = profileImageUrl
        self.subscriptionStatus = subscriptionStatus
        self.subscriptionCurrentPeriodEnd = subscriptionCurrentPeriodEnd
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
}

// MARK: - Billing Plan Enum
enum BillingPlan: String, Codable {
    case free = "free"
    case silver = "silver"
    case gold = "gold"

    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .silver:
            return "Silver"
        case .gold:
            return "Gold"
        }
    }

    var monthlyPrice: String {
        switch self {
        case .free:
            return "$0"
        case .silver:
            return "$14.99"
        case .gold:
            return "$29.99"
        }
    }
}

// MARK: - Procedure Model
struct Procedure: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let category: String
    let imageName: String?
}

// MARK: - Subscription Models
struct SubscriptionModel: Codable {
    let id: String
    let status: SubscriptionStatus
    let tier: SubscriptionTier?
    let currentPeriodEnd: Date?

    enum CodingKeys: String, CodingKey {
        case id = "stripe_subscription_id"
        case status = "subscription_status"
        case tier = "subscription_tier"
        case currentPeriodEnd = "subscription_current_period_end"
    }
}

enum SubscriptionStatus: String, Codable {
    case active
    case canceled
    case pastDue = "past_due"
    case trialing
    case incomplete
    case incompleteExpired = "incomplete_expired"
    case unpaid
}

enum SubscriptionTier: String, Codable {
    case silver
    case gold
}

// MARK: - Transaction Model
struct TransactionModel: Codable, Identifiable {
    let id: String
    let userId: String
    let transactionType: TransactionType
    let amountCents: Int
    let currency: String
    let status: TransactionStatus
    let stripePaymentIntentId: String?
    let stripeSubscriptionId: String?
    let stripeInvoiceId: String?
    let metadata: AnyCodable?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case transactionType = "transaction_type"
        case amountCents = "amount_cents"
        case currency
        case status
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case stripeSubscriptionId = "stripe_subscription_id"
        case stripeInvoiceId = "stripe_invoice_id"
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum TransactionType: String, Codable {
    case subscription
    case booking
    case refund
}

enum TransactionStatus: String, Codable {
    case pending
    case succeeded
    case failed
    case canceled
    case refunded
}

// MARK: - Payment Models

/// Request model for creating a Payment Intent
struct CreatePaymentIntentRequest: Codable {
    let amountCents: Int
    let currency: String
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case amountCents = "amount_cents"
        case currency
        case metadata
    }
}

/// Response model from create-payment-intent Edge Function
struct CreatePaymentIntentResponse: Codable {
    let clientSecret: String
    let paymentIntentId: String
    let ephemeralKey: String
    let customer: String
    let publishableKey: String

    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
        case paymentIntentId = "payment_intent_id"
        case ephemeralKey = "ephemeral_key"
        case customer
        case publishableKey = "publishable_key"
    }
}

/// Request model for creating a Subscription
struct CreateSubscriptionRequest: Codable {
    let priceId: String
    let tier: String

    enum CodingKeys: String, CodingKey {
        case priceId = "price_id"
        case tier
    }
}

/// Response model from create-subscription Edge Function
struct CreateSubscriptionResponse: Codable {
    let clientSecret: String
    let subscriptionId: String
    let ephemeralKey: String
    let customer: String
    let publishableKey: String

    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
        case subscriptionId = "subscription_id"
        case ephemeralKey = "ephemeral_key"
        case customer
        case publishableKey = "publishable_key"
    }
}

// MARK: - Usage Tracking Models

struct UsageQuota: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let periodStart: Date
    let periodEnd: Date

    let messagesUsed: Int
    let imagesUsed: Int
    let creditsUsed: Int

    let messagesLimit: Int
    let imagesLimit: Int
    let creditsLimit: Int

    let subscriptionTier: SubscriptionTier?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case messagesUsed = "messages_used"
        case imagesUsed = "images_used"
        case creditsUsed = "credits_used"
        case messagesLimit = "messages_limit"
        case imagesLimit = "images_limit"
        case creditsLimit = "credits_limit"
        case subscriptionTier = "subscription_tier"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Computed properties
    var messagesRemaining: Int { max(0, messagesLimit - messagesUsed) }
    var imagesRemaining: Int { max(0, imagesLimit - imagesUsed) }
    var creditsRemaining: Int { max(0, creditsLimit - creditsUsed) }

    var hasExceededAnyLimit: Bool {
        messagesUsed >= messagesLimit ||
        imagesUsed >= imagesLimit ||
        creditsUsed >= creditsLimit
    }
}

// Error response from Edge Function when quota exceeded
struct QuotaExceededError: Codable {
    let error: String
    let code: String
    let limitType: String
    let usage: UsageSnapshot
    let periodEnd: String

    struct UsageSnapshot: Codable {
        let messages: LimitInfo
        let images: LimitInfo
        let credits: LimitInfo
    }

    struct LimitInfo: Codable {
        let used: Int
        let limit: Int
    }
}

// Tier-specific quota configuration
struct TierQuotaLimits {
    let messagesLimit: Int
    let imagesLimit: Int
    let creditsLimit: Int

    static func limits(for tier: SubscriptionTier) -> TierQuotaLimits {
        switch tier {
        case .silver:
            return TierQuotaLimits(messagesLimit: 30, imagesLimit: 5, creditsLimit: 80)
        case .gold:
            return TierQuotaLimits(messagesLimit: 75, imagesLimit: 15, creditsLimit: 210)
        }
    }
}
