//
//  Models.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import Foundation

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromUser: Bool
    let timestamp: String
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
