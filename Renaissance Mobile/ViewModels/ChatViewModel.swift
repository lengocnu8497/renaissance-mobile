//
//  ChatViewModel.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/6/25.
//

import Foundation
import SwiftUI
import Supabase

@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var isLoading = false
    var isTyping = false
    var errorMessage: String?

    // MARK: - Initialization
    init() {
        // Start with an initial greeting from the concierge
        addInitialGreeting()
    }

    // MARK: - Public Methods

    /// Send a user message with optional image and get AI response
    func sendMessage(_ text: String, imageData: Data? = nil) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imageData != nil else { return }

        // Add user message
        let userMessage = ChatMessage(
            text: text,
            isFromUser: true,
            timestamp: getCurrentTimestamp(),
            responseId: nil,
            imageData: imageData
        )
        messages.append(userMessage)

        // Clear error state
        errorMessage = nil

        // Show typing indicator
        isTyping = true

        do {
            // Add a placeholder AI message for streaming
            let placeholderMessage = ChatMessage(
                text: "",
                isFromUser: false,
                timestamp: getCurrentTimestamp(),
                responseId: nil,
                imageData: nil
            )
            messages.append(placeholderMessage)

            // Hide typing indicator since we're now showing the streaming message
            isTyping = false

            // Get the previous response ID (from the last AI message before the placeholder)
            let previousResponseId = messages.dropLast().last(where: { !$0.isFromUser })?.responseId

            // Call Supabase Edge Function with streaming
            // The streaming will update the placeholder message in real-time
            let response = try await callAIFunction(
                userMessage: text,
                previousResponseId: previousResponseId,
                imageData: imageData
            )

            // Update the final message with the complete response
            if let lastIndex = messages.lastIndex(where: { !$0.isFromUser }) {
                messages[lastIndex] = ChatMessage(
                    text: response.reply,
                    isFromUser: false,
                    timestamp: messages[lastIndex].timestamp,
                    responseId: response.responseId,
                    imageData: nil
                )
            }

        } catch {
            // Hide typing indicator
            isTyping = false

            // Handle error
            errorMessage = "Failed to get response. Please try again."

            // Add error message to chat
            let errorMsg = ChatMessage(
                text: "Sorry, I'm having trouble connecting right now. Please try again.",
                isFromUser: false,
                timestamp: getCurrentTimestamp(),
                responseId: nil,
                imageData: nil
            )
            messages.append(errorMsg)

            print("Error calling AI function: \(error.localizedDescription)")
        }
    }

    /// Add an initial message (e.g., from search bar)
    func addInitialUserMessage(_ text: String) {
        let userMessage = ChatMessage(
            text: text,
            isFromUser: true,
            timestamp: getCurrentTimestamp(),
            responseId: nil,
            imageData: nil
        )
        messages.append(userMessage)

        // Automatically send to AI
        Task {
            await sendMessage(text)
        }
    }

    // MARK: - Private Methods

    private func addInitialGreeting() {
        let greeting = ChatMessage(
            text: "Hello! Welcome to Renaissance. I'm your personal beauty concierge. How can I assist you today?",
            isFromUser: false,
            timestamp: getCurrentTimestamp(),
            responseId: nil,
            imageData: nil
        )
        messages.append(greeting)
    }

    private func callAIFunction(
        userMessage: String,
        previousResponseId: String?,
        imageData: Data? = nil
    ) async throws -> ChatAIResponse {
        // Prepare the request payload with Codable struct
        let conversationHistory = messages.map { msg in
            ConversationMessage(
                role: msg.isFromUser ? "user" : "assistant",
                content: msg.text
            )
        }

        // Convert image to base64 if provided
        var imageBase64: String? = nil
        if let imageData = imageData {
            imageBase64 = imageData.base64EncodedString()
        }

        let requestBody = ChatAIRequest(
            message: userMessage,
            conversationHistory: conversationHistory,
            previousResponseId: previousResponseId,
            imageBase64: imageBase64
        )

        // Convert request body to Data
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(requestBody)

        // Build the URL for the Edge Function
        let functionURL = URL(string: "\(EnvironmentConfig.supabaseURL)/functions/v1/chat-ai")!

        // Create the request
        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authorization header with the current session token
        if let session = try? await supabase.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(EnvironmentConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")

        // Create a streaming URLSession
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to AI service"])
        }

        var fullText = ""
        var finalResponseId: String?

        // Process the Server-Sent Events stream
        for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))

                guard let data = jsonString.data(using: .utf8),
                      let event = try? JSONDecoder().decode(StreamEvent.self, from: data) else {
                    continue
                }

                switch event.type {
                case "delta":
                    // Append delta to full text
                    fullText += event.delta ?? ""
                    finalResponseId = event.responseId

                    // Update the last message in real-time on main thread
                    await MainActor.run {
                        if let lastIndex = messages.lastIndex(where: { !$0.isFromUser }) {
                            messages[lastIndex] = ChatMessage(
                                text: fullText,
                                isFromUser: false,
                                timestamp: messages[lastIndex].timestamp,
                                responseId: finalResponseId,
                                imageData: nil
                            )
                        }
                    }

                case "done":
                    // Final message received
                    fullText = event.reply ?? fullText
                    finalResponseId = event.responseId
                    break

                case "error":
                    throw NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: event.error ?? "Unknown error"])

                default:
                    break
                }
            }
        }

        return ChatAIResponse(reply: fullText, responseId: finalResponseId)
    }

    private func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Date())
    }
}

// MARK: - Request/Response Models

struct ChatAIRequest: Encodable {
    let message: String
    let conversationHistory: [ConversationMessage]
    let previousResponseId: String?
    let imageBase64: String?
}

struct ConversationMessage: Encodable {
    let role: String
    let content: String
}

struct ChatAIResponse: Decodable {
    let reply: String
    let responseId: String? // OpenAI response ID for next request
}

// MARK: - Streaming Event Model

struct StreamEvent: Decodable {
    let type: String
    let delta: String?
    let reply: String?
    let responseId: String?
    let error: String?
}
