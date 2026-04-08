//
//  ChatView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI
import PhotosUI
import Supabase
import Auth
import Network

private enum CC {
    static let shell = Color(hex: "#EEF1E8")
    static let bg = Color(hex: "#F6F7F2")
    static let surface = Color(hex: "#FBFCF8")
    static let card = Color(hex: "#EDF1E8")
    static let cardStrong = Color(hex: "#E1E7DA")
    static let text = Color(hex: "#1F261D")
    static let muted = Color(hex: "#687064")
    static let primary = Color(hex: "#516048")
    static let primaryInk = Color(hex: "#314030")
    static let primarySoft = Color(hex: "#D9E3CE")
    static let rose = Color(hex: "#B07B7A")
    static let roseSoft = Color(hex: "#F1DDDA")
    static let border = Color.black.opacity(0.05)
    static let shadow = Color(red: 90/255, green: 103/255, blue: 80/255).opacity(0.10)
}

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showQuotaExceeded = false
    @State private var onboardingPaymentViewModel = OnboardingPaymentViewModel()
    @State private var showPaymentError = false
    @State private var paymentErrorMessage = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var isOnline = true
    @State private var hasInitialized = false
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
                messagesList
                disclaimer
                    .padding(.bottom, 96)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            messageInput
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showQuotaExceeded) {
            QuotaExceededView(
                reason: viewModel.quotaExceededReason ?? "You've exceeded your quota",
                weeklyPrice: onboardingPaymentViewModel.weeklyPriceInfo?.displayPrice ?? "...",
                monthlyPrice: onboardingPaymentViewModel.monthlyPriceInfo?.displayPrice ?? "...",
                yearlyPrice: onboardingPaymentViewModel.yearlyPlanPriceInfo?.displayPrice ?? "...",
                onUpgrade: { tier in
                    await handleUpgrade(tier: tier)
                },
                onDismiss: {
                    showQuotaExceeded = false
                    viewModel.quotaExceeded = false
                    viewModel.quotaExceededReason = nil
                    viewModel.errorMessage = nil
                }
            )
            .task {
                if onboardingPaymentViewModel.weeklyPriceInfo == nil {
                    await onboardingPaymentViewModel.fetchPrices()
                }
            }
        }
        .alert("Payment Error", isPresented: $showPaymentError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(paymentErrorMessage)
        }
        .onChange(of: viewModel.quotaExceeded) { _, exceeded in
            if exceeded {
                showQuotaExceeded = true
            }
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

    private func handleUpgrade(tier: SubscriptionTier) async {
        let result = await onboardingPaymentViewModel.purchaseSubscription(tier: tier)
        switch result {
        case .success:
            showQuotaExceeded = false
            viewModel.quotaExceeded = false
            viewModel.quotaExceededReason = nil
            viewModel.errorMessage = nil
        case .cancelled:
            break
        case .pending:
            paymentErrorMessage = onboardingPaymentViewModel.errorMessage ?? "Your App Store purchase is pending approval."
            showPaymentError = true
        case .failed(let message):
            paymentErrorMessage = message
            showPaymentError = true
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

                Button(action: {
                    Task {
                        await viewModel.startNewChat()
                    }
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(CC.primaryInk)
                        .frame(width: 44, height: 44)
                        .background(CC.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(CC.border, lineWidth: 1)
                        )
                }
                .disabled(viewModel.isLoading || viewModel.isTyping)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 14)

            VStack(spacing: 4) {
                Text("Ask Rena")
                    .font(.custom("Manrope", size: 25))
                    .fontWeight(.heavy)
                    .foregroundColor(CC.text)
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
                    if !viewModel.starterPrompts.isEmpty {
                        promptStarterRow
                    }

                    dateDivider

                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            onUnlockTap: message.isLockedPreview ? {
                                showQuotaExceeded = true
                            } : nil
                        )
                            .id(message.id)
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
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .onChange(of: viewModel.messages.count) { _, _ in
                    if viewModel.checkAndOfferConsultationPrep() {
                        // Consultation prep offer just appeared — scroll to it
                        withAnimation {
                            proxy.scrollTo("consultationPrepOffer", anchor: .bottom)
                        }
                    } else if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
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

    private var dateDivider: some View {
        Text("Today")
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

    private var disclaimer: some View {
        EmptyView()
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
                HStack(alignment: .bottom, spacing: 12) {
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

                    HStack {
                        TextField("Ask about this photo or your recovery...", text: $messageText)
                            .font(.custom("PlusJakartaSans-Regular", size: 14))
                            .foregroundColor(CC.text)
                            .disabled(viewModel.isLoading)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                sendMessage()
                            }
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(CC.border, lineWidth: 1)
                    )

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 46, height: 46)
                            .background((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil) ? CC.cardStrong : CC.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .disabled((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil) || viewModel.isLoading)
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
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .background(CC.bg)
        }
    }

    private var promptStarterRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Prompt Starters")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                        .foregroundColor(CC.muted)
                        .textCase(.uppercase)
                        .tracking(2)
                }
                Spacer()
                RenaissanceAgentAvatar(size: 26)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.starterPrompts, id: \.self) { prompt in
                        Button {
                            Task { await viewModel.sendMessage(prompt) }
                        } label: {
                            Text(prompt)
                                .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                                .foregroundColor(CC.primaryInk)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(CC.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(16)
        .background(CC.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(CC.border, lineWidth: 1)
        )
    }

}

#Preview {
    ChatView()
}
