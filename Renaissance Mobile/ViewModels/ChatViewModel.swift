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

    // Quota state
    var quotaExceeded = false
    var quotaExceededReason: String?

    // Current conversation
    var currentConversation: ChatConversation?

    // Services
    private let databaseService: ChatDatabaseService
    private let usageService: UsageTrackingService

    // MARK: - Initialization
    init(
        databaseService: ChatDatabaseService = ChatDatabaseService(supabase: supabase),
        usageService: UsageTrackingService = UsageTrackingService(supabase: supabase)
    ) {
        self.databaseService = databaseService
        self.usageService = usageService

        // Load or create conversation
        Task {
            await loadOrCreateConversation()
        }
    }

    // MARK: - Public Methods

    /// Start a new chat session - clears UI and creates fresh conversation
    func startNewChat() async {
        // Clear the current messages from UI
        messages = []
        currentConversation = nil
        errorMessage = nil
        isTyping = false
        quotaExceeded = false
        quotaExceededReason = nil

        // Create a new conversation with greeting
        await createNewConversation()
    }

    /// Send a user message with optional image and get AI response
    func sendMessage(_ text: String, imageData: Data? = nil) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imageData != nil else { return }

        // CHECK QUOTA BEFORE SENDING
        let hasImage = imageData != nil
        do {
            let (canSend, reason) = try await usageService.canSendMessage(hasImage: hasImage)

            if !canSend {
                quotaExceeded = true
                quotaExceededReason = reason
                errorMessage = reason
                return
            }

            // Clear quota exceeded state
            quotaExceeded = false
            quotaExceededReason = nil
        } catch {
            quotaExceeded = true
            quotaExceededReason = error.localizedDescription
            errorMessage = error.localizedDescription
            return
        }

        // Ensure we have a conversation
        if currentConversation == nil {
            await loadOrCreateConversation()
        }

        guard let conversation = currentConversation else {
            errorMessage = "Failed to create conversation"
            return
        }

        // Get user ID
        guard let userId = try? await supabase.auth.session.user.id else {
            errorMessage = "User not authenticated"
            return
        }

        // Upload image if provided
        var imageUrl: String?
        let messageId = UUID()

        if let imageData = imageData {
            do {
                imageUrl = try await databaseService.uploadImage(
                    imageData,
                    conversationId: conversation.id,
                    messageId: messageId
                )
            } catch {
                print("Failed to upload image: \(error)")
                // Continue without image URL
            }
        }

        // Create user message
        let userMessage = ChatMessage(
            id: messageId,
            conversationId: conversation.id,
            userId: userId,
            messageText: text,
            isFromUser: true,
            createdAt: Date(),
            hasImage: imageData != nil,
            imageUrl: imageUrl,
            imageData: imageData
        )
        messages.append(userMessage)

        // Save user message to database
        Task {
            do {
                _ = try await databaseService.saveMessage(userMessage)
            } catch {
                print("Failed to save user message: \(error)")
            }
        }

        // Clear error state
        errorMessage = nil

        // Show typing indicator (stays visible until first streaming delta arrives)
        isTyping = true

        do {
            // Get the previous response ID from the last AI message
            let previousResponseId = messages.last(where: { !$0.isFromUser })?.responseId

            // Track response time
            let startTime = Date()

            // Call Supabase Edge Function with streaming
            // Message is created on first delta and updated in real-time
            let response = try await callAIFunction(
                userMessage: text,
                previousResponseId: previousResponseId,
                imageData: imageData,
                conversationId: conversation.id
            )

            let responseTime = Int(Date().timeIntervalSince(startTime) * 1000) // milliseconds

            // Ensure typing indicator is hidden after streaming completes
            isTyping = false

            // Update the final message with complete metadata
            if let lastIndex = messages.lastIndex(where: { !$0.isFromUser }) {
                var finalMessage = messages[lastIndex]
                finalMessage = ChatMessage(
                    id: finalMessage.id,
                    conversationId: conversation.id,
                    userId: userId,
                    messageText: response.reply,
                    isFromUser: false,
                    createdAt: finalMessage.createdAt,
                    openaiResponseId: response.responseId,
                    openaiModel: response.model,
                    tokensUsed: response.tokensUsed,
                    responseTimeMs: responseTime
                )
                messages[lastIndex] = finalMessage

                // Save AI message to database
                Task {
                    do {
                        _ = try await databaseService.saveMessage(finalMessage)
                    } catch {
                        print("Failed to save AI message: \(error)")
                    }
                }
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

    /// Load existing conversation or create a new one
    private func loadOrCreateConversation() async {
        do {
            // Try to get the most recent conversation
            let conversations = try await databaseService.getConversations(includeArchived: false)

            if let latestConversation = conversations.first {
                // Load existing conversation
                currentConversation = latestConversation
                await loadMessages(for: latestConversation.id)
            } else {
                // Create new conversation
                await createNewConversation()
            }
        } catch {
            print("Failed to load conversations: \(error)")
            // Create new conversation on error
            await createNewConversation()
        }
    }

    /// Create a new conversation session
    private func createNewConversation() async {
        do {
            let conversation = try await databaseService.createConversation(title: "New Chat")
            currentConversation = conversation

            // Add initial greeting
            await addInitialGreeting()
        } catch {
            print("Failed to create conversation: \(error)")
            errorMessage = "Failed to create conversation"
        }
    }

    /// Load messages for a conversation
    private func loadMessages(for conversationId: UUID) async {
        do {
            let loadedMessages = try await databaseService.getMessages(conversationId: conversationId)
            messages = loadedMessages

            // If no messages, add initial greeting
            if messages.isEmpty {
                await addInitialGreeting()
            }
        } catch {
            print("Failed to load messages: \(error)")
            // Start with greeting on error
            await addInitialGreeting()
        }
    }

    private func addInitialGreeting() async {
        guard let conversation = currentConversation,
              let userId = try? await supabase.auth.session.user.id else {
            return
        }

        let greeting = ChatMessage(
            conversationId: conversation.id,
            userId: userId,
            messageText: "Hello! Welcome to Renaissance. I'm your personal beauty concierge. How can I assist you today?",
            isFromUser: false,
            createdAt: Date()
        )
        messages.append(greeting)

        // Save greeting to database
        Task {
            do {
                _ = try await databaseService.saveMessage(greeting)
            } catch {
                print("Failed to save greeting: \(error)")
            }
        }
    }

    private func callAIFunction(
        userMessage: String,
        previousResponseId: String?,
        imageData: Data? = nil,
        conversationId: UUID
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
            imageBase64: imageBase64,
            conversationId: conversationId.uuidString
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

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to AI service"])
        }

        // Check for quota exceeded (HTTP 429)
        if httpResponse.statusCode == 429 {
            quotaExceeded = true
            quotaExceededReason = "You've exceeded your quota limit"
            throw NSError(domain: "ChatViewModel", code: 429, userInfo: [
                NSLocalizedDescriptionKey: "You've exceeded your quota limit"
            ])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to AI service"])
        }

        var fullText = ""
        var finalResponseId: String?
        var aiMessageId: UUID?
        let messageCreatedAt = Date()

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

                    // Update UI on main thread
                    await MainActor.run {
                        // On first delta: hide typing indicator and create the AI message
                        if aiMessageId == nil {
                            isTyping = false
                            aiMessageId = UUID()
                            let newMessage = ChatMessage(
                                id: aiMessageId!,
                                conversationId: conversationId,
                                userId: nil,
                                messageText: fullText,
                                isFromUser: false,
                                createdAt: messageCreatedAt,
                                openaiResponseId: finalResponseId
                            )
                            messages.append(newMessage)
                        } else {
                            // Subsequent deltas: update existing message
                            if let lastIndex = messages.lastIndex(where: { $0.id == aiMessageId }) {
                                messages[lastIndex] = ChatMessage(
                                    id: aiMessageId!,
                                    conversationId: conversationId,
                                    userId: messages[lastIndex].userId,
                                    messageText: fullText,
                                    isFromUser: false,
                                    createdAt: messageCreatedAt,
                                    openaiResponseId: finalResponseId
                                )
                            }
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

        return ChatAIResponse(reply: fullText, responseId: finalResponseId, model: nil, tokensUsed: nil)
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
    let conversationId: String
}

struct ConversationMessage: Encodable {
    let role: String
    let content: String
}

struct ChatAIResponse: Decodable {
    let reply: String
    let responseId: String? // OpenAI response ID for next request
    let model: String?
    let tokensUsed: Int?

    enum CodingKeys: String, CodingKey {
        case reply
        case responseId
        case model
        case tokensUsed = "tokens_used"
    }
}

// MARK: - Streaming Event Model

struct StreamEvent: Decodable {
    let type: String
    let delta: String?
    let reply: String?
    let responseId: String?
    let error: String?
}
