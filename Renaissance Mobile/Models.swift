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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
}

// MARK: - Billing Plan Enum
enum BillingPlan: String, Codable {
    case free = "free"
    case basic = "basic"
    case premium = "premium"

    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .basic:
            return "Basic"
        case .premium:
            return "Premium"
        }
    }

    var monthlyPrice: String {
        switch self {
        case .free:
            return "$0"
        case .basic:
            return "$9.99"
        case .premium:
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
    case basic
    case premium
    case vip
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

// MARK: - AnyCodable Helper
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }
}
