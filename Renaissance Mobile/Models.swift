//
//  Models.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import Foundation
import UIKit

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromUser: Bool
    let timestamp: String
    let responseId: String? // OpenAI response ID for maintaining reasoning context
    let imageData: Data? // Optional image attachment

    init(text: String, isFromUser: Bool, timestamp: String, responseId: String?, imageData: Data? = nil) {
        self.text = text
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.responseId = responseId
        self.imageData = imageData
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
