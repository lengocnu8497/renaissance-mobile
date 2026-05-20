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

    // First name shown in the welcome card greeting
    var firstName: String = ""

    // Follow-up chips shown above the input bar after each AI response
    var followUpSuggestions: [String] = []

    var lastAIReplyIsTimeline: Bool {
        guard let last = messages.last(where: { !$0.isFromUser }) else { return false }
        let t = last.text
        let weekHits = ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5", "Week 6", "Week 7", "Week 8"]
            .filter { t.contains($0) }.count
        let phaseHits = ["Phase 1", "Phase 2", "Phase 3"].filter { t.contains($0) }.count
        let dayHits = t.contains("Day 1") && (t.contains("Day 7") || t.contains("Day 14") || t.contains("Week 2"))
        return weekHits >= 2 || phaseHits >= 2 || dayHits
    }

    private var sessionMessageCount = 0
    private var conversationPersisted = false

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
        async let conv: () = createNewConversation()
        async let name: () = loadFirstName()
        await conv
        await name
    }

    private func loadFirstName() async {
        guard firstName.isEmpty else { return }
        if let profile = try? await profileService.getUserProfile(),
           let full = profile.fullName, !full.isEmpty {
            firstName = full.components(separatedBy: " ").first ?? full
        }
    }

    // MARK: - Public Methods

    /// Injects an invisible system context string that is prepended to the first AI call.
    /// Used by ComparisonChatSheet to pass entry metrics and photo context.
    func injectComparisonContext(_ text: String) {
        userContextNote = text
    }

    var isProcedureContextChat: Bool {
        procedureContext != nil
    }

    var chatTitle: String {
        "Ask Rena"
    }

    var chatSubtitle: String {
        ""
    }

    var hasUserMessages: Bool {
        messages.contains { $0.isFromUser }
    }

    // "Planning · Rhinoplasty" or "Recovering · Lip Filler" — nil if no journey data
    var journeyContextLabel: String? {
        let name = procedureContext?.name ?? OnboardingStore.pendingProcedureName
        guard let name, !name.isEmpty else { return nil }
        let branch = OnboardingStore.pendingBranch ?? "planning"
        let branchLabel: String
        switch branch {
        case "recovering":              branchLabel = "Recovering"
        case "research", "researching": branchLabel = "Researching"
        default:                        branchLabel = "Planning"
        }
        return "\(branchLabel) · \(name)"
    }

    // "Day 14 of prep", "Day 3 of recovery", or "12 days until procedure"
    var journeyDayLabel: String? {
        guard let date = OnboardingStore.pendingProcedureDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let procedureDay = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: procedureDay, to: today).day ?? 0
        let branch = OnboardingStore.pendingBranch ?? "planning"
        if branch == "recovering" {
            return "Day \(max(1, days + 1)) of recovery"
        } else if days < 0 {
            let n = abs(days)
            return "\(n) day\(n == 1 ? "" : "s") until procedure"
        } else {
            return "Day \(days + 1) of prep"
        }
    }

    var starterPrompts: [String] {
        let branch = OnboardingStore.pendingBranch ?? ""
        let hasProcedure = procedureContext != nil || (OnboardingStore.pendingProcedureName?.isEmpty == false)

        if hasProcedure && branch == "recovering" {
            return [
                "Is this swelling normal?",
                "When can I exercise again?",
                "Bruising timeline",
                "Scar care tips",
                "What's normal this week?",
                "Medications I can take"
            ]
        }

        if hasProcedure {
            return [
                "What's normal week 1?",
                "Managing swelling",
                "Questions for my surgeon",
                "Pain levels",
                "Sleep position tips",
                "Diet & prep tips"
            ]
        }

        return [
            "Compare two procedures",
            "What to ask at consultation?",
            "Can you look at this photo?",
            "Recovery timeline",
            "Risks & tradeoffs",
            "Find a specialist"
        ]
    }

    struct MessageGroup: Identifiable {
        let id: Date
        let dateLabel: String
        let messages: [ChatMessage]
    }

    var groupedMessages: [MessageGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        var result: [MessageGroup] = []
        var currentDay: Date?
        var currentMessages: [ChatMessage] = []
        for message in messages {
            let msgDay = calendar.startOfDay(for: message.createdAt)
            if msgDay != currentDay {
                if !currentMessages.isEmpty, let day = currentDay {
                    result.append(MessageGroup(
                        id: day,
                        dateLabel: Self.dayLabel(day, today: today, yesterday: yesterday, calendar: calendar),
                        messages: currentMessages
                    ))
                }
                currentDay = msgDay
                currentMessages = [message]
            } else {
                currentMessages.append(message)
            }
        }
        if !currentMessages.isEmpty, let day = currentDay {
            result.append(MessageGroup(
                id: day,
                dateLabel: Self.dayLabel(day, today: today, yesterday: yesterday, calendar: calendar),
                messages: currentMessages
            ))
        }
        return result
    }

    private static func dayLabel(_ day: Date, today: Date, yesterday: Date, calendar: Calendar) -> String {
        if calendar.isDate(day, inSameDayAs: today) { return "Today" }
        if calendar.isDate(day, inSameDayAs: yesterday) { return "Yesterday" }
        let formatter = DateFormatter()
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: today), day > weekAgo {
            formatter.dateFormat = "EEEE"
        } else if calendar.component(.year, from: day) == calendar.component(.year, from: today) {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: day)
    }

    /// Start a new chat session - clears UI and creates fresh conversation
    func startNewChat() async {
        messages = []
        currentConversation = nil
        conversationPersisted = false
        errorMessage = nil
        isTyping = false
        quotaExceeded = false
        quotaExceededReason = nil
        procedureContext = nil
        consultationPrepOffered = false
        followUpSuggestions = []
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
            if firstName.isEmpty, let full = profile.fullName, !full.isEmpty {
                firstName = full.components(separatedBy: " ").first ?? full
            }
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
                conversationPersisted = true
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

        // Persist the conversation on the first real user message (lazy creation)
        if !conversationPersisted, let conv = currentConversation {
            do {
                let persisted = try await databaseService.persistConversation(conv)
                currentConversation = persisted
                conversationPersisted = true
            } catch {
                print("Failed to persist conversation: \(error)")
            }
        }

        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

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
            messageText: normalizedText,
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

        // CHECK QUOTA AFTER SHOWING THE USER MESSAGE SO THE UPGRADE MOMENT
        // FEELS LIKE A CONTINUATION OF THE CONVERSATION RATHER THAN A BLOCKER.
        let hasImage = imageData != nil
        do {
            let (canSend, reason) = try await usageService.canSendMessage(hasImage: hasImage)

            if !canSend {
                quotaExceeded = true
                quotaExceededReason = reason
                errorMessage = reason
                appendLockedPreviewMessage(
                    in: conversation,
                    userId: userId,
                    prompt: normalizedText,
                    includedImage: hasImage
                )
                return
            }

            quotaExceeded = false
            quotaExceededReason = nil
        } catch {
            quotaExceeded = true
            quotaExceededReason = error.localizedDescription
            errorMessage = error.localizedDescription
            appendLockedPreviewMessage(
                in: conversation,
                userId: userId,
                prompt: normalizedText,
                includedImage: hasImage
            )
            return
        }

        // Clear error state and stale follow-ups
        errorMessage = nil
        followUpSuggestions = []

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
            sessionMessageCount += 1
            Analytics.askRenaUsed(countPerSession: sessionMessageCount)

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

            // Derive follow-up chips from the reply
            self.followUpSuggestions = deriveFollowUpChips(from: response.reply)

            // Save AI message and update conversation preview for history list
            let previewText = String(response.reply.prefix(120))
                .components(separatedBy: .newlines).joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
            let totalMessages = messages.count
            Task {
                do {
                    _ = try await databaseService.saveMessage(finalMessage)
                } catch {
                    print("Failed to save AI message: \(error)")
                }
                if var conv = currentConversation {
                    var meta = conv.metadata ?? [:]
                    meta["last_preview"] = AnyCodable(previewText)
                    meta["message_count"] = AnyCodable(totalMessages)
                    conv.metadata = meta
                    try? await databaseService.updateConversation(conv)
                }
            }

        } catch {
            // Hide typing indicator
            isTyping = false

            // Handle error
            let failureMessage = error.localizedDescription
            errorMessage = failureMessage

            // Add error message to chat
            let errorMsg = ChatMessage(
                text: (error as NSError).code == 403
                    ? failureMessage
                    : "Sorry, I'm having trouble connecting right now. Please try again.",
                isFromUser: false,
                timestamp: getCurrentTimestamp(),
                responseId: nil,
                imageData: nil
            )
            messages.append(errorMsg)

            print("Error calling AI function: \(error.localizedDescription)")
        }
    }

    private func appendLockedPreviewMessage(
        in conversation: ChatConversation,
        userId: UUID,
        prompt: String,
        includedImage: Bool
    ) {
        let preview = ChatMessage(
            conversationId: conversation.id,
            userId: userId,
            messageText: buildLockedPreviewText(for: prompt, includedImage: includedImage),
            isFromUser: false,
            createdAt: Date(),
            metadata: [
                "is_locked_preview": AnyCodable(true),
                "locked_preview_title": AnyCodable("Rena drafted an answer")
            ]
        )
        messages.append(preview)
    }

    private func buildLockedPreviewText(for prompt: String, includedImage: Bool) -> String {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let topic = trimmedPrompt.isEmpty ? "your question" : "“\(trimmedPrompt)”"
        let imageLine = includedImage
            ? "I also reviewed the image you attached and tailored the response around what it could suggest."
            : "I tailored the response around your question and your recovery context."

        return """
        Here’s Rena’s personalized answer for \(topic).

        \(imageLine)
        I outlined the most likely explanation, what feels normal versus worth watching, and the next question I’d ask your provider.
        Unlock your subscription to read the full answer.
        """
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
                conversationPersisted = true
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

    /// Create a new conversation session (local only — persisted on first real user message)
    private func createNewConversation(title: String = "New Chat") async {
        guard let userId = supabase.auth.currentUser?.id else {
            errorMessage = "Failed to create conversation"
            return
        }
        currentConversation = ChatConversation(userId: userId, title: title)
        conversationPersisted = false
        await addInitialGreeting()
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
        // Greeting is local-only — saved to DB only after the conversation is persisted
        // (which happens when the user sends their first real message)
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

    private func deriveFollowUpChips(from replyText: String) -> [String] {
        let text = replyText.lowercased()
        if text.contains("swelling") || text.contains("swell") {
            return ["How long will swelling last?", "What reduces swelling?", "When should I be worried?"]
        }
        if text.contains("bruising") || text.contains("bruise") {
            return ["Normal bruising timeline?", "What speeds healing?", "Ice vs heat?"]
        }
        if text.contains("scar") || text.contains("incision") {
            return ["Best scar treatments?", "When does it fade?", "Sun protection tips"]
        }
        if text.contains("pain") || text.contains("discomfort") {
            return ["What pain is normal?", "Pain management tips", "When does it get better?"]
        }
        if text.contains("exercise") || text.contains("workout") || text.contains("activity") {
            return ["When can I walk normally?", "Light activity timeline", "What should I avoid?"]
        }
        if text.contains("sleep") || text.contains("position") || text.contains("pillow") {
            return ["Best sleep position?", "How long to elevate?", "Pillow recommendations?"]
        }
        if text.contains("diet") || text.contains("food") || text.contains("eat") || text.contains("drink") {
            return ["Foods that speed healing?", "What to avoid?", "Staying hydrated"]
        }
        if text.contains("medication") || text.contains("medicine") || text.contains("pill") {
            return ["Can I take ibuprofen?", "Medications to avoid", "Pain relief options"]
        }
        if text.contains("consult") || text.contains("surgeon") || text.contains("appointment") {
            return ["Questions to ask my surgeon", "What to bring?", "How to prepare?"]
        }
        if text.contains("anesthesia") || text.contains("anesthetic") || text.contains("sedation") {
            return ["Types of anesthesia?", "Anesthesia risks", "Recovery from anesthesia"]
        }
        if text.contains("timeline") || text.contains("week") || text.contains("month") {
            return ["Full recovery timeline?", "Week-by-week breakdown", "What to expect next?"]
        }
        let branch = OnboardingStore.pendingBranch ?? "planning"
        if branch == "recovering" {
            return ["Is this normal?", "Recovery tips", "Call my surgeon?"]
        }
        return ["Tell me more", "What should I expect?", "Questions to ask?"]
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

        let (data, httpResponse) = try await performAIFunctionRequest(
            request,
            allowEntitlementRetry: true
        )

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

    private func performAIFunctionRequest(
        _ request: URLRequest,
        allowEntitlementRetry: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "ChatViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to connect to AI service"]
            )
        }

        if httpResponse.statusCode == 403,
           allowEntitlementRetry,
           await shouldRetryAfterEntitlementSync() {
            _ = await SubscriptionStore.shared.ensurePremiumAccessIsSynced()
            try? await Task.sleep(nanoseconds: 500_000_000)
            return try await performAIFunctionRequest(
                request,
                allowEntitlementRetry: false
            )
        }

        return (data, httpResponse)
    }

    private func shouldRetryAfterEntitlementSync() async -> Bool {
        await MainActor.run {
            SubscriptionStore.shared.hasActiveSubscription
        }
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
