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

    // Procedure context — set when deep-linking from ProcedureDetailView
    var procedureContext: Procedure?

    // Whether the AI has already offered the Consultation Prep Flow for this procedure
    var consultationPrepOffered = false

    // Personalization context injected on the first AI call for procedure-context sessions
    private var userContextNote: String? = nil
    private var shouldResetModelContext = false

    // Services
    private let databaseService: ChatDatabaseService
    private let usageService: UsageTrackingService
    private let profileService = UserProfileService(supabase: supabase)
    private let insightsService = RecoveryInsightsService()
    private let savedProcedureService = SavedProcedureService(supabase: supabase)

    // MARK: - Initialization
    init(
        databaseService: ChatDatabaseService = ChatDatabaseService(supabase: supabase),
        usageService: UsageTrackingService = UsageTrackingService(supabase: supabase)
    ) {
        self.databaseService = databaseService
        self.usageService = usageService
        // Initialization is deferred to ChatView.onAppear via initialize()
        // to avoid a race condition with startChatWithProcedure.
    }

    /// Called from ChatView.onAppear for the plain (no initial message) case.
    func initialize() async {
        await createNewConversation()
    }

    // MARK: - Public Methods

    var isProcedureContextChat: Bool {
        procedureContext != nil
    }

    var chatTitle: String {
        "Ask Rena"
    }

    var chatSubtitle: String {
        ""
    }

    var starterPrompts: [String] {
        if let procedure = procedureContext {
            return [
                "What should I ask in my \(procedure.name) consultation?",
                "What is recovery usually like for \(procedure.name)?",
                "Can you explain the main risks and tradeoffs?"
            ]
        }

        return [
            "Help me compare two procedures",
            "What should I ask at a consultation?",
            "Can you look at this photo?"
        ]
    }

    /// Start a new chat session - clears UI and creates fresh conversation
    func startNewChat() async {
        messages = []
        currentConversation = nil
        errorMessage = nil
        isTyping = false
        quotaExceeded = false
        quotaExceededReason = nil
        procedureContext = nil
        consultationPrepOffered = false
        userContextNote = nil
        shouldResetModelContext = false

        await createNewConversation()
    }

    /// Start a chat pre-loaded with a procedure context.
    /// Pass `savedProcedureId` to automatically link the new conversation to a saved procedure.
    func startChatWithProcedure(_ procedure: Procedure, initialMessage: String, savedProcedureId: UUID? = nil) async {
        procedureContext = procedure
        // If the initial message is itself a consultation prep request, mark it as already
        // offered so the offer card doesn't appear redundantly after the AI responds.
        consultationPrepOffered = initialMessage.contains("Consultation Prep")
        messages = []
        currentConversation = nil
        errorMessage = nil
        isTyping = false
        quotaExceeded = false
        quotaExceededReason = nil
        userContextNote = nil
        shouldResetModelContext = false

        // Fetch profile + most recent insight in parallel for context injection
        async let profileFetch: UserProfile? = try? profileService.getUserProfile()
        let recentInsight = insightsService.fetchMostRecentCached()
        if let profile = await profileFetch {
            let context = buildUserContext(profile: profile, insight: recentInsight, procedure: procedure)
            userContextNote = context.isEmpty ? nil : context
        }

        await createNewConversation(title: procedure.name)

        // Link conversation to saved procedure in the background
        if let savedId = savedProcedureId, let conversation = currentConversation {
            Task {
                try? await savedProcedureService.linkConversation(conversation.id, to: savedId)
            }
        }

        await sendMessage(initialMessage)
    }

    /// Load an existing conversation by ID (used when re-opening a research session).
    func loadExistingConversation(_ conversationId: UUID) async {
        messages = []
        currentConversation = nil
        errorMessage = nil
        isTyping = false
        quotaExceeded = false
        quotaExceededReason = nil
        procedureContext = nil
        consultationPrepOffered = true  // don't offer prep again on existing sessions
        userContextNote = nil
        shouldResetModelContext = false

        do {
            if let conversation = try await databaseService.getConversation(id: conversationId) {
                currentConversation = conversation
                await loadMessages(for: conversationId)
            } else {
                await createNewConversation()
            }
        } catch {
            await createNewConversation()
        }
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
        guard let userId = supabase.auth.currentUser?.id else {
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
            let ignoreConversationHistory = shouldResetModelContext
            let previousResponseId = ignoreConversationHistory ? nil : messages.last(where: { !$0.isFromUser })?.responseId

            // On the first message of a procedure-context session, prepend the user's
            // personalization context to what the AI receives. The bubble still shows
            // only `text` — the context is invisible in the UI.
            let aiMessageText: String
            if let context = userContextNote, previousResponseId == nil {
                aiMessageText = "\(context)\n\n---\n\n\(text)"
                userContextNote = nil  // consume once
            } else {
                aiMessageText = text
            }

            // Track response time
            let startTime = Date()

            // Call Supabase Edge Function with streaming
            // Message is created on first delta and updated in real-time
            let response = try await callAIFunction(
                userMessage: aiMessageText,
                previousResponseId: previousResponseId,
                ignoreConversationHistory: ignoreConversationHistory,
                imageData: imageData,
                conversationId: conversation.id
            )
            shouldResetModelContext = response.resetContext

            let responseTime = Int(Date().timeIntervalSince(startTime) * 1000) // milliseconds

            // Ensure typing indicator is hidden after streaming completes
            isTyping = false
            await MainActor.run { SoundHapticManager.shared.playReplyWoosh() }

            // Update existing AI message if created during streaming, or create a new one
            let finalMessage: ChatMessage
            if let aiMsgId = response.streamingMessageId,
               let existingIndex = messages.lastIndex(where: { $0.id == aiMsgId }) {
                // Update the message created during delta streaming
                finalMessage = ChatMessage(
                    id: aiMsgId,
                    conversationId: conversation.id,
                    userId: userId,
                    messageText: response.reply,
                    isFromUser: false,
                    createdAt: messages[existingIndex].createdAt,
                    openaiResponseId: response.responseId,
                    openaiModel: response.model,
                    hasImage: response.generatedImageUrl != nil,
                    tokensUsed: response.tokensUsed,
                    responseTimeMs: responseTime,
                    generatedImageUrl: response.generatedImageUrl
                )
                messages[existingIndex] = finalMessage
            } else {
                // No message was created during streaming (no delta events) — append a new one
                finalMessage = ChatMessage(
                    id: UUID(),
                    conversationId: conversation.id,
                    userId: userId,
                    messageText: response.reply,
                    isFromUser: false,
                    createdAt: Date(),
                    openaiResponseId: response.responseId,
                    openaiModel: response.model,
                    hasImage: response.generatedImageUrl != nil,
                    tokensUsed: response.tokensUsed,
                    responseTimeMs: responseTime,
                    generatedImageUrl: response.generatedImageUrl
                )
                messages.append(finalMessage)
            }

            // Save AI message to database
            Task {
                do {
                    _ = try await databaseService.saveMessage(finalMessage)
                } catch {
                    print("Failed to save AI message: \(error)")
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
    private func createNewConversation(title: String = "New Chat") async {
        do {
            let conversation = try await databaseService.createConversation(title: title)
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
              let userId = supabase.auth.currentUser?.id else {
            return
        }

        let greetingText: String
        if let proc = procedureContext {
            greetingText = "Hello! I'm Rena — your personal beauty concierge. I see you're exploring **\(proc.name)**. I'm ready to help you research this procedure, answer your questions, and prepare you for your consultation. What would you like to know?"
        } else {
            greetingText = "Hello! I'm Rena -- your personal beauty concierge assistant. How can I assist you today?"
        }

        let greeting = ChatMessage(
            conversationId: conversation.id,
            userId: userId,
            messageText: greetingText,
            isFromUser: false,
            createdAt: Date()
        )
        messages.append(greeting)

        Task {
            do {
                _ = try await databaseService.saveMessage(greeting)
            } catch {
                print("Failed to save greeting: \(error)")
            }
        }
    }

    /// After a procedure-context AI response, check if we should offer the Consultation Prep Flow
    func checkAndOfferConsultationPrep() -> Bool {
        guard let _ = procedureContext,
              !consultationPrepOffered,
              messages.filter({ !$0.isFromUser }).count >= 2 else {
            return false
        }
        consultationPrepOffered = true
        return true
    }

    // MARK: - User Context Builder

    private func buildUserContext(profile: UserProfile, insight: RecoveryInsights?, procedure: Procedure) -> String {
        // Only build context if there's meaningful data to include
        var details: [String] = []

        if let age = profile.ageRange { details.append("Age range: \(age)") }
        if let gender = profile.gender { details.append("Gender: \(gender)") }
        if let ethnicity = profile.raceEthnicity { details.append("Ethnicity/background: \(ethnicity)") }
        if let priors = profile.previousProcedures, !priors.isEmpty {
            details.append("Previous procedures: \(priors.joined(separator: ", "))")
        }
        if let flags = profile.healthFlags, !flags.isEmpty {
            details.append("Health considerations: \(flags.joined(separator: ", "))")
        }
        if let goals = profile.aestheticGoals, !goals.isEmpty {
            details.append("Aesthetic goals: \(goals.joined(separator: ", "))")
        }
        if let areas = profile.bodyAreasOfInterest, !areas.isEmpty {
            details.append("Areas of interest: \(areas.joined(separator: ", "))")
        }
        if let insight = insight {
            details.append("Current recovery (\(insight.procedureName), \(insight.entryCount) entries, \(insight.trend.label)): \(insight.summary)")
            if let next = insight.nextSteps {
                details.append("Rena's active next steps for them: \(next)")
            }
        }

        guard !details.isEmpty else { return "" }

        return """
        [About me — use this to make your answer specific to my situation. \
        Do not list or echo this back; just let it inform your response naturally.]
        \(details.joined(separator: "\n"))
        """
    }

    private func callAIFunction(
        userMessage: String,
        previousResponseId: String?,
        ignoreConversationHistory: Bool = false,
        imageData: Data? = nil,
        conversationId: UUID
    ) async throws -> ChatAIResponse {
        // Only send conversation history if we don't have a previousResponseId
        // (OpenAI maintains context via response ID, so history is redundant and wastes TPM)
        let conversationHistory: [ConversationMessage]?
        if ignoreConversationHistory {
            conversationHistory = nil
        } else if previousResponseId != nil {
            conversationHistory = nil
        } else {
            // Trim to last 6 messages to avoid unbounded payload growth
            conversationHistory = messages.suffix(6).map { msg in
                ConversationMessage(
                    role: msg.isFromUser ? "user" : "assistant",
                    content: msg.text
                )
            }
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
        let functionURL = URL(string: "\(AppConfig.supabaseURL)/functions/v1/chat-ai")!

        // Create the request
        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authorization header with the current session token
        if let session = try? await supabase.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")

        // Call the edge function
        let (data, response) = try await URLSession.shared.data(for: request)

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
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            print("AI service error - Status: \(httpResponse.statusCode), Body: \(errorBody)")

            let errorMessage: String
            switch httpResponse.statusCode {
            case 401:
                errorMessage = "Authentication failed. Please sign in again."
            case 403:
                errorMessage = "No active subscription. Please upgrade to use the AI concierge."
            case 500:
                errorMessage = "Server error. Please try again later."
            default:
                errorMessage = "Failed to connect to AI service (HTTP \(httpResponse.statusCode))"
            }
            throw NSError(domain: "ChatViewModel", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        // Parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from AI service"])
        }

        let fullText = json["reply"] as? String ?? ""
        let finalResponseId = json["responseId"] as? String
        let model = json["model"] as? String
        let tokensUsed = json["tokens_used"] as? Int
        let generatedImageUrl = json["generated_image_url"] as? String
        let resetContext = json["reset_context"] as? Bool ?? false

        return ChatAIResponse(reply: fullText, responseId: finalResponseId, model: model, tokensUsed: tokensUsed, generatedImageUrl: generatedImageUrl, streamingMessageId: nil, resetContext: resetContext)
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
    let conversationHistory: [ConversationMessage]?
    let previousResponseId: String?
    let imageBase64: String?
    let conversationId: String
}

struct ConversationMessage: Encodable {
    let role: String
    let content: String
}

struct ChatAIResponse {
    let reply: String
    let responseId: String? // OpenAI response ID for next request
    let model: String?
    let tokensUsed: Int?
    let generatedImageUrl: String? // DALL-E generated image URL
    let streamingMessageId: UUID? // ID of message created during delta streaming
    let resetContext: Bool
}

// MARK: - Streaming Event Model

struct StreamEvent: Decodable {
    let type: String
    let delta: String?
    let reply: String?
    let responseId: String?
    let error: String?
    let generatedImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case type
        case delta
        case reply
        case responseId
        case error
        case generatedImageUrl = "generated_image_url"
    }
}
