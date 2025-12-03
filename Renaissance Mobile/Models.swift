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
