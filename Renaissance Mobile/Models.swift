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

    var isPinned: Bool { (metadata?["is_pinned"]?.value as? Bool) == true }
    var lastPreview: String? { metadata?["last_preview"]?.value as? String }
    var storedMessageCount: Int? { metadata?["message_count"]?.value as? Int }
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

    // AI-generated image URL (from DALL-E)
    var generatedImageUrl: String?

    // Computed properties for backward compatibility with UI
    var text: String { messageText }
    var isLockedPreview: Bool {
        (metadata?["is_locked_preview"]?.value as? Bool) == true
    }

    var lockedPreviewTitle: String? {
        metadata?["locked_preview_title"]?.value as? String
    }

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
        case generatedImageUrl = "generated_image_url"
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
        imageData: Data? = nil,
        generatedImageUrl: String? = nil
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
        self.generatedImageUrl = generatedImageUrl
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
        self.generatedImageUrl = nil
    }
}

// MARK: - Notification Mode

enum NotificationMode: String, CaseIterable, Codable {
    case off    = "off"
    case daily  = "daily"
    case weekly = "weekly"

    var label: String {
        switch self {
        case .off:    return "Off"
        case .daily:  return "Daily"
        case .weekly: return "Weekly"
        }
    }

    var subtitle: String {
        switch self {
        case .off:    return "No recovery reminders"
        case .daily:  return "Once a day — pick your time"
        case .weekly: return "Once a week — pick your day and time"
        }
    }

    var icon: String {
        switch self {
        case .off:    return "bell.slash.fill"
        case .daily:  return "calendar.badge.clock"
        case .weekly: return "calendar"
        }
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
    var subscriptionTier: SubscriptionTier?
    var subscriptionStatus: SubscriptionStatus?
    var subscriptionCurrentPeriodEnd: Date?
    var subscriptionProvider: SubscriptionProvider?
    var subscriptionId: String?
    var appStoreProductId: String?
    var appStoreOriginalTransactionId: String?
    var appStoreEnvironment: AppStoreEnvironment?
    let createdAt: Date
    var updatedAt: Date
    var metadata: [String: AnyCodable]?

    // MARK: - AI Personalization Context
    var gender: String?
    var ageRange: String?
    var raceEthnicity: String?
    var aestheticGoals: [String]?
    var proceduresOfInterest: [String]?
    var previousProcedures: [String]?
    var healthFlags: [String]?
    var bodyAreasOfInterest: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case phoneNumber = "phone_number"
        case zipCode = "zip_code"
        case billingPlan = "billing_plan"
        case profileImageUrl = "profile_image_url"
        case subscriptionTier = "subscription_tier"
        case subscriptionStatus = "subscription_status"
        case subscriptionCurrentPeriodEnd = "subscription_current_period_end"
        case subscriptionProvider = "subscription_provider"
        case subscriptionId = "subscription_id"
        case appStoreProductId = "app_store_product_id"
        case appStoreOriginalTransactionId = "app_store_original_transaction_id"
        case appStoreEnvironment = "app_store_environment"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case metadata
        case gender
        case ageRange = "age_range"
        case raceEthnicity = "race_ethnicity"
        case aestheticGoals = "aesthetic_goals"
        case proceduresOfInterest = "procedures_of_interest"
        case previousProcedures = "previous_procedures"
        case healthFlags = "health_flags"
        case bodyAreasOfInterest = "body_areas_of_interest"
    }

    init(
        id: UUID = UUID(),
        fullName: String? = nil,
        email: String? = nil,
        phoneNumber: String? = nil,
        zipCode: String? = nil,
        billingPlan: BillingPlan = .free,
        profileImageUrl: String? = nil,
        subscriptionTier: SubscriptionTier? = nil,
        subscriptionStatus: SubscriptionStatus? = nil,
        subscriptionCurrentPeriodEnd: Date? = nil,
        subscriptionProvider: SubscriptionProvider? = nil,
        subscriptionId: String? = nil,
        appStoreProductId: String? = nil,
        appStoreOriginalTransactionId: String? = nil,
        appStoreEnvironment: AppStoreEnvironment? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadata: [String: AnyCodable]? = nil,
        gender: String? = nil,
        ageRange: String? = nil,
        raceEthnicity: String? = nil,
        aestheticGoals: [String]? = nil,
        proceduresOfInterest: [String]? = nil,
        previousProcedures: [String]? = nil,
        healthFlags: [String]? = nil,
        bodyAreasOfInterest: [String]? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phoneNumber = phoneNumber
        self.zipCode = zipCode
        self.billingPlan = billingPlan
        self.profileImageUrl = profileImageUrl
        self.subscriptionTier = subscriptionTier
        self.subscriptionStatus = subscriptionStatus
        self.subscriptionCurrentPeriodEnd = subscriptionCurrentPeriodEnd
        self.subscriptionProvider = subscriptionProvider
        self.subscriptionId = subscriptionId
        self.appStoreProductId = appStoreProductId
        self.appStoreOriginalTransactionId = appStoreOriginalTransactionId
        self.appStoreEnvironment = appStoreEnvironment
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.gender = gender
        self.ageRange = ageRange
        self.raceEthnicity = raceEthnicity
        self.aestheticGoals = aestheticGoals
        self.proceduresOfInterest = proceduresOfInterest
        self.previousProcedures = previousProcedures
        self.healthFlags = healthFlags
        self.bodyAreasOfInterest = bodyAreasOfInterest
    }
}

enum SubscriptionProvider: String, Codable {
    case stripe
    case appStore = "app_store"
}

enum AppStoreEnvironment: String, Codable {
    case sandbox
    case production
    case xcode
}

// MARK: - Billing Plan Enum
enum BillingPlan: String, Codable {
    case free = "free"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value {
        case "free":
            self = .free
        case "weekly", "silver":
            self = .weekly
        case "monthly", "gold":
            self = .monthly
        case "yearly", "annual":
            self = .yearly
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown billing plan: \(value)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        switch self {
        case .free:    return "Free"
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .yearly:  return "Annual"
        }
    }
}

/// MARK: - Procedure Model
struct Procedure: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let category: String
    let recoveryDurationDays: Int
    let recoveryDurationLabel: String
    let isSurgical: Bool
    let sortOrder: Int

    // Extended detail fields (Pre-Procedure Research)
    var editorialSummary: String?
    var defaultConsultQuestions: [String]?
    var heroImageURL: String?
    var thumbnailImageURL: String?
    var mediaSource: String?
    var mediaLicenseType: String?
    var mediaAltText: String?
    var usageRightsConfirmed: Bool?
    var whoItsFor: String?
    var recoveryOverview: String?
    var whatIsNormal: String?
    var whatToWatchFor: String?
    var costRangeMin: Int?
    var costRangeMax: Int?
    var relatedProcedureIds: [UUID]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case category
        case recoveryDurationDays = "recovery_duration_days"
        case recoveryDurationLabel = "recovery_duration_label"
        case isSurgical = "is_surgical"
        case sortOrder = "sort_order"
        case editorialSummary = "editorial_summary"
        case defaultConsultQuestions = "default_consult_questions"
        case heroImageURL = "hero_image_url"
        case thumbnailImageURL = "thumbnail_image_url"
        case mediaSource = "media_source"
        case mediaLicenseType = "media_license_type"
        case mediaAltText = "media_alt_text"
        case usageRightsConfirmed = "usage_rights_confirmed"
        case whoItsFor = "who_its_for"
        case recoveryOverview = "recovery_overview"
        case whatIsNormal = "what_is_normal"
        case whatToWatchFor = "what_to_watch_for"
        case costRangeMin = "cost_range_min"
        case costRangeMax = "cost_range_max"
        case relatedProcedureIds = "related_procedure_ids"
    }

    var costRangeDisplay: String? {
        guard let min = costRangeMin, let max = costRangeMax else { return nil }
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.maximumFractionDigits = 0
        fmt.locale = Locale(identifier: "en_US")
        let minStr = fmt.string(from: NSNumber(value: min)) ?? "$\(min)"
        let maxStr = fmt.string(from: NSNumber(value: max)) ?? "$\(max)"
        return "\(minStr) – \(maxStr)"
    }
}

// MARK: - Saved Procedure Model
struct SavedProcedure: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID
    let procedureId: UUID
    var notes: String?
    var questions: [String]
    var conversationIds: [UUID]
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case procedureId = "procedure_id"
        case notes
        case questions
        case conversationIds = "conversation_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        procedureId = try container.decode(UUID.self, forKey: .procedureId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        questions = try container.decodeIfPresent([String].self, forKey: .questions) ?? []
        conversationIds = try container.decodeIfPresent([UUID].self, forKey: .conversationIds) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

// MARK: - Subscription Models
struct SubscriptionModel: Decodable {
    let id: String?
    let status: SubscriptionStatus?
    let tier: SubscriptionTier?
    let currentPeriodEnd: Date?
    let provider: SubscriptionProvider?
    let productId: String?
    let originalTransactionId: String?

    enum CodingKeys: String, CodingKey {
        case id = "subscription_id"
        case legacyStripeSubscriptionId = "stripe_subscription_id"
        case status = "subscription_status"
        case tier = "subscription_tier"
        case currentPeriodEnd = "subscription_current_period_end"
        case provider = "subscription_provider"
        case productId = "app_store_product_id"
        case originalTransactionId = "app_store_original_transaction_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? (try container.decodeIfPresent(String.self, forKey: .legacyStripeSubscriptionId))
        status = try container.decodeIfPresent(SubscriptionStatus.self, forKey: .status)
        tier = try container.decodeIfPresent(SubscriptionTier.self, forKey: .tier)
        currentPeriodEnd = try container.decodeIfPresent(Date.self, forKey: .currentPeriodEnd)
        provider = try container.decodeIfPresent(SubscriptionProvider.self, forKey: .provider)
        productId = try container.decodeIfPresent(String.self, forKey: .productId)
        originalTransactionId = try container.decodeIfPresent(String.self, forKey: .originalTransactionId)
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
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value {
        case "weekly", "silver":
            self = .weekly
        case "monthly", "gold":
            self = .monthly
        case "yearly", "annual":
            self = .yearly
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown subscription tier: \(value)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        switch self {
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .yearly:  return "Annual"
        }
    }
}

// MARK: - Transaction Model
struct TransactionModel: Decodable, Identifiable {
    let id: String
    let userId: String
    let transactionType: TransactionType
    let amountCents: Int
    let currency: String
    let status: TransactionStatus
    let paymentProvider: SubscriptionProvider?
    let subscriptionId: String?
    let storeTransactionId: String?
    let originalTransactionId: String?
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
        case paymentProvider = "payment_provider"
        case subscriptionId = "subscription_id"
        case storeTransactionId = "store_transaction_id"
        case originalTransactionId = "original_transaction_id"
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case stripeSubscriptionId = "stripe_subscription_id"
        case stripeInvoiceId = "stripe_invoice_id"
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        transactionType = try container.decode(TransactionType.self, forKey: .transactionType)
        amountCents = try container.decode(Int.self, forKey: .amountCents)
        currency = try container.decode(String.self, forKey: .currency)
        status = try container.decode(TransactionStatus.self, forKey: .status)
        paymentProvider = try container.decodeIfPresent(SubscriptionProvider.self, forKey: .paymentProvider)
        subscriptionId = try container.decodeIfPresent(String.self, forKey: .subscriptionId)
            ?? (try container.decodeIfPresent(String.self, forKey: .stripeSubscriptionId))
        storeTransactionId = try container.decodeIfPresent(String.self, forKey: .storeTransactionId)
            ?? (try container.decodeIfPresent(String.self, forKey: .stripePaymentIntentId))
        originalTransactionId = try container.decodeIfPresent(String.self, forKey: .originalTransactionId)
        stripePaymentIntentId = try container.decodeIfPresent(String.self, forKey: .stripePaymentIntentId)
        stripeSubscriptionId = try container.decodeIfPresent(String.self, forKey: .stripeSubscriptionId)
        stripeInvoiceId = try container.decodeIfPresent(String.self, forKey: .stripeInvoiceId)
        metadata = try container.decodeIfPresent(AnyCodable.self, forKey: .metadata)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
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
        case .weekly:
            return TierQuotaLimits(messagesLimit: 30, imagesLimit: 5, creditsLimit: 80)
        case .monthly:
            return TierQuotaLimits(messagesLimit: 75, imagesLimit: 15, creditsLimit: 210)
        case .yearly:
            return TierQuotaLimits(messagesLimit: 75, imagesLimit: 15, creditsLimit: 300)
        }
    }
}
