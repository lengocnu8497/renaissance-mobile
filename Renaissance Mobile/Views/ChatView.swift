//
//  ChatView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI
import PhotosUI
import StoreKit
import Supabase
import Auth
import Network

private enum CC {
    static let shell      = Color(hex: "#EEEEFF")
    static let bg         = Color(hex: "#FAFAFF")
    static let surface    = Color(hex: "#FFFFFF")
    static let card       = Color(hex: "#EAE7FF")
    static let cardStrong = Color(hex: "#E0DBFF")
    static let text       = Color(hex: "#1E1B4B")
    static let muted      = Color(hex: "#7B6FC0")
    static let primary    = Color(hex: "#6C63FF")
    static let primaryInk = Color(hex: "#2D2575")
    static let primarySoft = Color(hex: "#EAE7FF")
    static let border     = Color(hex: "#E0DBFF").opacity(0.8)
    static let shadow     = Color(hex: "#6C63FF").opacity(0.08)
}

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @State private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var savedToRoadmap = false
    @State private var showHistory = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var isOnline = true
    @State private var hasInitialized = false
    @State private var freeQuestionsRemaining = FreeUsageStore.questionsRemaining
    private let networkMonitor = NWPathMonitor()

    var initialMessage: String?
    var procedureContext: Procedure?
    var savedProcedureId: UUID?
    var conversationIdToLoad: UUID?
    var onBackButtonTapped: (() -> Void)?

    init(
        initialMessage: String? = nil,
        procedureContext: Procedure? = nil,
        savedProcedureId: UUID? = nil,
        conversationIdToLoad: UUID? = nil,
        onBackButtonTapped: (() -> Void)? = nil
    ) {
        self.initialMessage = initialMessage
        self.procedureContext = procedureContext
        self.savedProcedureId = savedProcedureId
        self.conversationIdToLoad = conversationIdToLoad
        self.onBackButtonTapped = onBackButtonTapped
    }

    var body: some View {
        ZStack {
            CC.shell.ignoresSafeArea()

            VStack(spacing: 0) {
                chatHeader
                if !subscriptionStore.hasActiveSubscription && viewModel.hasUserMessages {
                    freeUsageBar
                }
                messagesList
                disclaimer
                    .padding(.bottom, 96)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            messageInput
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showHistory) {
            ConversationHistoryView(
                onSelectConversation: { id in
                    showHistory = false
                    Task { await viewModel.loadExistingConversation(id) }
                },
                onNewConversation: {
                    showHistory = false
                    Task { await viewModel.startNewChat() }
                },
                onDismiss: { showHistory = false }
            )
        }
        .task(id: viewModel.currentConversation?.id) {
            if let convId = viewModel.currentConversation?.id {
                UserDefaults.standard.set(Date(), forKey: "rena.conv_seen.\(convId.uuidString)")
            }
        }
        .onChange(of: viewModel.isTyping) { _, isTyping in
            if !isTyping {
                freeQuestionsRemaining = FreeUsageStore.questionsRemaining
            }
            guard !isTyping,
                  viewModel.messages.filter({ !$0.isFromUser }).count == 1,
                  !UserDefaults.standard.bool(forKey: "rena.hasRequestedReview")
            else { return }
            UserDefaults.standard.set(true, forKey: "rena.hasRequestedReview")
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                requestReview()
            }
        }
        .onChange(of: viewModel.quotaExceeded) { _, _ in
            freeQuestionsRemaining = FreeUsageStore.questionsRemaining
        }
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            handleInitialMessage()
            startNetworkMonitoring()
        }
    }

    // MARK: - Initial Message Handler
    private func handleInitialMessage() {
        Task {
            if let conversationId = conversationIdToLoad {
                // Re-open an existing research session conversation
                await viewModel.loadExistingConversation(conversationId)
            } else if let procedure = procedureContext, let msg = initialMessage, !msg.isEmpty {
                // Deep-link with procedure context: full setup + send in one path
                await viewModel.startChatWithProcedure(procedure, initialMessage: msg, savedProcedureId: savedProcedureId)
            } else {
                // Always initialize the conversation first (creates greeting)
                await viewModel.initialize()
                if let msg = initialMessage, !msg.isEmpty {
                    await viewModel.sendMessage(msg)
                }
            }
        }
    }

    // MARK: - Network Monitoring
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                isOnline = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }

    // MARK: - Actions
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || selectedImageData != nil else { return }

        SoundHapticManager.shared.playSendWoosh()
        savedToRoadmap = false

        // Clear the input fields
        let imageData = selectedImageData
        messageText = ""
        selectedImageData = nil
        selectedImage = nil

        // Send message through ViewModel
        Task {
            await viewModel.sendMessage(text.isEmpty ? "What do you think about this photo?" : text, imageData: imageData)
        }
    }

    // MARK: - Subviews
    private var chatHeader: some View {
        ZStack {
            HStack {
                Button(action: {
                    if let onBackButtonTapped = onBackButtonTapped {
                        onBackButtonTapped()
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(CC.primaryInk)
                        .frame(width: 44, height: 44)
                        .background(CC.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(CC.border, lineWidth: 1)
                        )
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: { showHistory = true }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(CC.primaryInk)
                            .frame(width: 40, height: 40)
                            .background(CC.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(CC.border, lineWidth: 1)
                            )
                    }

                    Button(action: {
                        Task {
                            await viewModel.startNewChat()
                        }
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(CC.primaryInk)
                            .frame(width: 40, height: 40)
                            .background(CC.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(CC.border, lineWidth: 1)
                            )
                    }
                    .disabled(viewModel.isLoading || viewModel.isTyping)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 14)

            VStack(spacing: 3) {
                Text("Ask Rena")
                    .font(.custom("Outfit-Bold", size: 17))
                    .foregroundColor(CC.primaryInk)
                if let label = viewModel.journeyContextLabel {
                    Text(label)
                        .font(.custom("Outfit-Regular", size: 12))
                        .foregroundColor(CC.muted)
                }
            }
        }
        .padding(.top, 38)
        .background(CC.bg)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(CC.border),
            alignment: .bottom
        )
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    if !viewModel.hasUserMessages {
                        welcomeStateCard
                            .transition(.opacity)
                    } else {
                        ForEach(viewModel.groupedMessages) { group in
                            dateDivider(group.dateLabel)
                            ForEach(group.messages) { message in
                                MessageBubbleView(
                                    message: message,
                                    onUnlockTap: message.isLockedPreview ? { } : nil
                                )
                                .id(message.id)
                            }
                        }

                        // Consultation Prep offer — appears after 2nd AI reply in procedure context
                        if viewModel.consultationPrepOffered,
                           let procedure = viewModel.procedureContext {
                            ConsultationPrepOfferCard(procedureName: procedure.name) {
                                let prompt = """
                                Please give me a personalized Consultation Prep for \(procedure.name), formatted as three sections: \
                                1) A checklist of questions to ask my surgeon, \
                                2) Things I should proactively disclose to my provider, \
                                3) What to look for when evaluating a provider for this procedure.
                                """
                                Task { await viewModel.sendMessage(prompt) }
                            }
                            .id("consultationPrepOffer")
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        if viewModel.isTyping {
                            TypingIndicatorView()
                                .id("typing")
                        }

                        if viewModel.quotaExceeded {
                            InlinePaywallBubble(onSubscribed: {
                                viewModel.quotaExceeded = false
                                viewModel.quotaExceededReason = nil
                                viewModel.errorMessage = nil
                            })
                            .id("inlinePaywall")
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .animation(.easeInOut(duration: 0.2), value: viewModel.hasUserMessages)
                .onChange(of: viewModel.messages.count) { _, _ in
                    if viewModel.quotaExceeded {
                        withAnimation { proxy.scrollTo("inlinePaywall", anchor: .bottom) }
                    } else if viewModel.checkAndOfferConsultationPrep() {
                        withAnimation {
                            proxy.scrollTo("consultationPrepOffer", anchor: .bottom)
                        }
                    } else if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.quotaExceeded) { _, exceeded in
                    if exceeded {
                        withAnimation { proxy.scrollTo("inlinePaywall", anchor: .bottom) }
                    }
                }
                .onChange(of: viewModel.isTyping) { _, isTyping in
                    if isTyping {
                        withAnimation {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }
            .background(CC.bg)
        }
    }

    private func dateDivider(_ label: String) -> some View {
        Text(label)
            .font(.custom("PlusJakartaSans-SemiBold", size: 10))
            .foregroundColor(CC.muted)
            .tracking(1.8)
            .textCase(.uppercase)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(CC.surface.opacity(0.88))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(CC.border, lineWidth: 1))
            .padding(.top, 2)
    }

    private var roadmapSaveStrip: some View {
        HStack {
            Button {
                saveLastReplyToRoadmap()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: savedToRoadmap ? "checkmark" : "bookmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text(savedToRoadmap ? "Saved to Roadmap" : "Save to Roadmap")
                        .font(.custom("Outfit-SemiBold", size: 12))
                }
                .foregroundColor(savedToRoadmap ? CC.primary : CC.primaryInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(savedToRoadmap ? CC.card : CC.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(savedToRoadmap ? CC.primary.opacity(0.4) : CC.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(savedToRoadmap)

            Spacer()
        }
        .padding(.horizontal, 2)
        .animation(.easeInOut(duration: 0.2), value: savedToRoadmap)
    }

    private func saveLastReplyToRoadmap() {
        guard let last = viewModel.messages.last(where: { !$0.isFromUser }) else { return }
        let procedureName = viewModel.procedureContext?.name ?? OnboardingStore.pendingProcedureName ?? "General"
        let phaseLabel = viewModel.journeyDayLabel ?? "Recovery"
        var notes = (UserDefaults.standard.array(forKey: "rena.roadmapSavedNotes") as? [[String: String]]) ?? []
        notes.append([
            "text": last.text,
            "procedureName": procedureName,
            "phaseLabel": phaseLabel,
            "savedAt": ISO8601DateFormatter().string(from: Date())
        ])
        UserDefaults.standard.set(notes, forKey: "rena.roadmapSavedNotes")
        withAnimation(.easeInOut(duration: 0.2)) {
            savedToRoadmap = true
        }
        SoundHapticManager.shared.playButtonTick()
    }

    private var disclaimer: some View {
        EmptyView()
    }

    private var freeUsageBar: some View {
        let remaining = freeQuestionsRemaining
        let total = FreeUsageStore.monthlyLimit
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Free questions remaining")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .foregroundColor(CC.primaryInk)
                Capsule()
                    .fill(CC.shell)
                    .frame(height: 5)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            let fraction = total > 0 ? CGFloat(remaining) / CGFloat(total) : 0
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [CC.primary, Color(hex: "#8B7FF0")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, geo.size.width * fraction))
                        }
                    }
            }
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(remaining)")
                    .font(.custom("PlusJakartaSans-Bold", size: 20))
                    .foregroundColor(CC.primary)
                Text("/\(total)")
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundColor(CC.muted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(CC.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: CC.shadow, radius: 8, x: 0, y: 2)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(CC.bg)
    }

    private var messageInput: some View {
        VStack(spacing: 0) {
            // Error message banner
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.1))
            }

            // Image preview
            if let imageData = selectedImageData,
               let uiImage = UIImage(data: imageData) {
                HStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                        .overlay(
                            Button(action: {
                                selectedImageData = nil
                                selectedImage = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .offset(x: 5, y: -5),
                            alignment: .topTrailing
                        )
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 2)
                .background(CC.bg)
            }

            VStack(spacing: 10) {
                if !viewModel.quotaExceeded {
                    if viewModel.lastAIReplyIsTimeline {
                        roadmapSaveStrip
                    }
                    if !viewModel.followUpSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.followUpSuggestions, id: \.self) { chip in
                                    Button {
                                        SoundHapticManager.shared.playSendWoosh()
                                        Task { await viewModel.sendMessage(chip) }
                                    } label: {
                                        Text(chip)
                                            .font(.custom("Outfit-Regular", size: 12))
                                            .foregroundColor(CC.primaryInk)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 9)
                                            .background(CC.card)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(CC.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .transition(.opacity)
                    }
                }

                HStack(alignment: .bottom, spacing: 12) {
                    if !viewModel.quotaExceeded {
                        PhotosPicker(selection: $selectedImage, matching: .images) {
                            Image(systemName: "photo")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(CC.primary)
                                .frame(width: 46, height: 46)
                                .background(CC.card)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .onChange(of: selectedImage) { _, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                }
                            }
                        }
                    }

                    HStack {
                        TextField(
                            viewModel.quotaExceeded
                                ? "Subscribe to continue..."
                                : "Ask about your procedure or recovery...",
                            text: $messageText
                        )
                        .font(.custom("Outfit-Regular", size: 14))
                        .foregroundColor(CC.text)
                        .disabled(viewModel.isLoading || viewModel.quotaExceeded)
                        .focused($isTextFieldFocused)
                        .onSubmit { sendMessage() }
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                    .background(CC.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(CC.border, lineWidth: 1)
                    )

                    let canSend = (!messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImageData != nil)
                        && !viewModel.isLoading && !viewModel.quotaExceeded
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 46, height: 46)
                            .background(canSend ? CC.primary : CC.cardStrong)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .disabled(!canSend)
                }

                Text("Rena offers supportive guidance, not a diagnosis. Contact your provider for urgent concerns.")
                    .font(.custom("PlusJakartaSans-Regular", size: 11))
                    .foregroundColor(CC.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(CC.surface.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.65), lineWidth: 1)
                    )
                    .shadow(color: CC.shadow, radius: 20, x: 0, y: 6)
            )
            .opacity(viewModel.quotaExceeded ? 0.5 : 1)
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .background(CC.bg)
        }
    }

    // MARK: - Welcome State

    private var welcomeStateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Context strip — only when journey data exists
            if let journeyLabel = viewModel.journeyContextLabel {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(CC.primary)
                            .frame(width: 24, height: 24)
                        renaLogoMark
                            .frame(width: 14, height: 14)
                    }
                    Text(journeyLabel)
                        .font(.custom("Outfit-SemiBold", size: 11))
                        .foregroundColor(CC.primaryInk)
                    if let dayLabel = viewModel.journeyDayLabel {
                        Text("·")
                            .font(.custom("Outfit-Regular", size: 11))
                            .foregroundColor(CC.muted)
                        Text(dayLabel)
                            .font(.custom("Outfit-Regular", size: 11))
                            .foregroundColor(CC.muted)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(CC.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(CC.border, lineWidth: 1))
            }

            // Welcome card
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(CC.surface)
                        .frame(width: 44, height: 44)
                        .shadow(color: CC.primary.opacity(0.15), radius: 8, x: 0, y: 3)
                    renaLogoMark
                        .frame(width: 24, height: 24)
                }

                let greeting = viewModel.firstName.isEmpty
                    ? "What's on your mind?"
                    : "Hi \(viewModel.firstName), what's on your mind?"
                Text(greeting)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundColor(CC.primaryInk)
                    .lineSpacing(2)

                Text("Ask anything about your procedure, recovery, or what to expect. I'll give you a personalized answer in seconds.")
                    .font(.custom("Outfit-Light", size: 13))
                    .foregroundColor(CC.muted)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                LinearGradient(
                    colors: [CC.card, CC.cardStrong.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(CC.border, lineWidth: 1))

            // Suggestion chips
            if !viewModel.starterPrompts.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Suggested")
                        .font(.custom("Outfit-SemiBold", size: 10))
                        .foregroundColor(CC.muted)
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .padding(.leading, 2)

                    let prompts = viewModel.starterPrompts
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 8
                    ) {
                        ForEach(prompts, id: \.self) { prompt in
                            promptChip(prompt)
                        }
                    }
                }
            }
        }
    }

    private func promptChip(_ prompt: String) -> some View {
        Button {
            Task { await viewModel.sendMessage(prompt) }
        } label: {
            Text(prompt)
                .font(.custom("Outfit-Regular", size: 12))
                .foregroundColor(CC.primaryInk)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(CC.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(CC.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var renaLogoMark: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let radii: [(CGFloat, CGFloat)] = [
                (size.width * 0.47, 1.2),
                (size.width * 0.33, 1.0),
                (size.width * 0.21, 1.2)
            ]
            let ringColor = Color(hex: "#8B7FF0")
            let accentColor = Color(hex: "#6C63FF")
            for (i, (r, w)) in radii.enumerated() {
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(i == 2 ? accentColor : ringColor),
                    lineWidth: w
                )
            }
            let dotR = size.width * 0.07
            context.fill(
                Path(ellipseIn: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)),
                with: .color(accentColor)
            )
        }
    }

}

// MARK: - Inline Paywall Bubble

private struct InlinePaywallBubble: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore
    let onSubscribed: () -> Void

    @State private var selectedTier: SubscriptionTier = .yearly
    @State private var isPurchasing = false
    @State private var statusMessage: String?
    @State private var didNotify = false

    private let tiers: [SubscriptionTier] = [.yearly, .monthly]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RenaissanceAgentAvatar(size: 34)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 10) {
                // Gradient header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Unlock unlimited Ask Rena")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundColor(.white)
                        .lineSpacing(2)
                    Text("Answers in seconds, personalized to your procedure and recovery stage.")
                        .font(.custom("PlusJakartaSans-Regular", size: 12))
                        .foregroundColor(Color.white.opacity(0.82))
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#6C63FF"), Color(hex: "#8B7FF0")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Plan cards
                VStack(spacing: 6) {
                    ForEach(tiers, id: \.self) { tier in
                        planCard(for: tier)
                    }
                }

                // Trust row
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#6C63FF"))
                    Text(annualHasFreeTrial && selectedTier == .yearly
                         ? "7-day free trial · cancel anytime"
                         : "Cancel anytime · no hidden fees")
                        .font(.custom("PlusJakartaSans-Regular", size: 12))
                        .foregroundColor(Color(hex: "#2D2575"))
                }

                // Status message
                if let msg = statusMessage {
                    Text(msg)
                        .font(.custom("PlusJakartaSans-Regular", size: 12))
                        .foregroundColor(Color(hex: "#5B50D6"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                // CTA button
                Button {
                    Task { await purchaseSelectedTier() }
                } label: {
                    Group {
                        if subscriptionStore.isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text(ctaText)
                                .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .background(Color(hex: "#6C63FF"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color(hex: "#6C63FF").opacity(0.35), radius: 8, x: 0, y: 4)
                .disabled(subscriptionStore.isPurchasing)
            }

            Spacer(minLength: 0)
        }
        .task { await subscriptionStore.prepare() }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
            guard subscriptionStore.hasActiveSubscription, !didNotify else { return }
            didNotify = true
            onSubscribed()
        }
    }

    private func planCard(for tier: SubscriptionTier) -> some View {
        let isSelected = selectedTier == tier
        let product = subscriptionStore.product(for: tier)
        let displayPrice = product?.displayPrice ?? (tier == .yearly ? "$89.99" : "$19.99")

        return Button { selectedTier = tier } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text(tier == .yearly ? "Annual Plan" : "Monthly Plan")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                            .foregroundColor(isSelected ? Color(hex: "#2D2575") : Color(hex: "#7B6FC0"))

                        if tier == .yearly {
                            Text("Best Value")
                                .font(.custom("PlusJakartaSans-Bold", size: 10))
                                .foregroundColor(Color(hex: "#5B50D6"))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color(hex: "#D4CCFF"))
                                .clipShape(Capsule())

                            if let savings = annualSavingsLabel {
                                Text(savings)
                                    .font(.custom("PlusJakartaSans-Bold", size: 10))
                                    .foregroundColor(Color(hex: "#3D8A4E"))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: "#D4EDDA"))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(displayPrice)
                            .font(.custom("PlusJakartaSans-Bold", size: 18))
                            .foregroundColor(isSelected ? Color(hex: "#2D2575") : Color(hex: "#7B6FC0"))
                        Text(tier == .yearly ? "/yr" : "/mo")
                            .font(.custom("PlusJakartaSans-Regular", size: 12))
                            .foregroundColor(Color(hex: "#7B6FC0"))
                        if tier == .yearly, let eq = monthlyEquivalent {
                            Text("· \(eq)/mo")
                                .font(.custom("PlusJakartaSans-Regular", size: 11))
                                .foregroundColor(Color(hex: "#7B6FC0"))
                        }
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isSelected ? Color(hex: "#6C63FF") : Color(hex: "#D4CCFF"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected
                          ? LinearGradient(colors: [Color(hex: "#EAE7FF").opacity(0.92), Color(hex: "#F5F4FF").opacity(0.96)],
                                           startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [Color.white.opacity(0.94), Color(hex: "#FAFAFF").opacity(0.92)],
                                           startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Color(hex: "#8B7FF0").opacity(0.42) : Color(hex: "#6C63FF").opacity(0.10),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var annualHasFreeTrial: Bool {
        subscriptionStore.product(for: .yearly)?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    private var annualSavingsLabel: String? {
        guard let annual = subscriptionStore.product(for: .yearly),
              let monthly = subscriptionStore.product(for: .monthly) else { return "Save 50%" }
        let annualPrice = (annual.price as NSDecimalNumber).doubleValue
        let monthlyPrice = (monthly.price as NSDecimalNumber).doubleValue
        let annualized = monthlyPrice * 12
        guard annualized > 0 else { return nil }
        let pct = Int(((annualized - annualPrice) / annualized * 100).rounded())
        return pct > 0 ? "Save \(pct)%" : nil
    }

    private var monthlyEquivalent: String? {
        guard let product = subscriptionStore.product(for: .yearly),
              let period = product.subscription?.subscriptionPeriod,
              period.unit == .year, period.value > 0 else { return nil }
        let monthlyPrice = product.price / Decimal(period.value * 12)
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = product.priceFormatStyle.locale
        fmt.currencyCode = product.priceFormatStyle.currencyCode
        return fmt.string(from: monthlyPrice as NSDecimalNumber)
    }

    private var ctaText: String {
        if annualHasFreeTrial && selectedTier == .yearly {
            return "Start 7-day free trial"
        }
        return "Continue with \(selectedTier == .yearly ? "Annual" : "Monthly")"
    }

    @MainActor
    private func purchaseSelectedTier() async {
        statusMessage = nil
        let result = await subscriptionStore.purchase(selectedTier)
        switch result {
        case .success:
            guard !didNotify else { return }
            didNotify = true
            onSubscribed()
        case .pending:
            statusMessage = "Your App Store purchase is pending approval."
        case .cancelled, .failed:
            break
        }
    }
}

#Preview {
    ChatView()
}
