//
//  ChatView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI
import PhotosUI
import StripePaymentSheet
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
    static let border = Color.black.opacity(0.05)
    static let shadow = Color(red: 90/255, green: 103/255, blue: 80/255).opacity(0.10)
}

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showImagePicker = false
    @State private var showQuotaExceeded = false
    @State private var subscriptionViewModel = SubscriptionViewModel()
    @State private var paymentViewModel = PaymentViewModel()
    @State private var onboardingPaymentViewModel = OnboardingPaymentViewModel()
    @State private var showPaymentError = false
    @State private var paymentErrorMessage = ""
    @State private var hasCheckedSubscription = false
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
                silverPrice: onboardingPaymentViewModel.silverPriceInfo?.displayPrice ?? "...",
                goldPrice: onboardingPaymentViewModel.goldPriceInfo?.displayPrice ?? "...",
                annualPrice: onboardingPaymentViewModel.annualPriceInfo?.displayPrice ?? "...",
                onUpgrade: { tier in
                    await handleUpgrade(tier: tier)
                },
                onDismiss: {
                    showQuotaExceeded = false
                    hasCheckedSubscription = false
                    viewModel.quotaExceeded = false
                    viewModel.quotaExceededReason = nil
                    viewModel.errorMessage = nil
                }
            )
            .task {
                if onboardingPaymentViewModel.silverPriceInfo == nil {
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

    private func checkSubscriptionStatus() async {
        // Only check once per session
        guard !hasCheckedSubscription else { return }
        hasCheckedSubscription = true

        // Check if user has silver or gold subscription
        do {
            guard let userId = supabase.auth.currentUser?.id else {
                return
            }

            let profile: UserProfile = try await supabase.database
                .from("user_profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value

            // If user doesn't have silver or gold, show subscription modal
            if profile.billingPlan != .silver && profile.billingPlan != .gold {
                viewModel.quotaExceeded = true
                viewModel.quotaExceededReason = "Subscribe to unlock AI chat and get personalized beauty recommendations"
                viewModel.errorMessage = viewModel.quotaExceededReason
            }
        } catch {
            print("Error checking subscription: \(error)")
        }
    }

    private func handleUpgrade(tier: SubscriptionTier) async {
        // Store the selected tier for later use after payment
        let selectedTier = tier

        // Get price ID from environment config based on selected tier
        let priceId: String
        switch tier {
        case .silver:
            priceId = AppConfig.stripeSilverPriceId
        case .gold:
            priceId = AppConfig.stripeGoldPriceId
        case .annual:
            priceId = AppConfig.stripeAnnualPriceId
        }

        // Validate price ID is configured
        guard !priceId.contains("REPLACE_WITH_YOUR") else {
            paymentErrorMessage = "Subscription plan not configured. Please add Stripe price IDs to AppConfig."
            showPaymentError = true
            return
        }

        // Step 1: Create subscription and get client secret
        guard let subscriptionResult = await subscriptionViewModel.createSubscription(
            priceId: priceId,
            tier: tier
        ) else {
            paymentErrorMessage = subscriptionViewModel.errorMessage ?? "Failed to create subscription"
            showPaymentError = true
            return
        }

        let clientSecret = subscriptionResult.clientSecret
        let subscriptionId = subscriptionResult.subscriptionId

        // Step 2: Configure Payment Sheet for subscription
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Renaissance"
        configuration.allowsDelayedPaymentMethods = true
        configuration.returnURL = "renaissance://payment-complete"

        // Appearance customization - light theme for input fields
        var appearance = PaymentSheet.Appearance()
        appearance.colors.primary = UIColor(red: 208/255, green: 187/255, blue: 149/255, alpha: 1.0) // Renaissance gold
        appearance.colors.background = UIColor(red: 247/255, green: 247/255, blue: 246/255, alpha: 1.0)
        appearance.colors.componentBackground = UIColor.white
        appearance.colors.componentBorder = UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1.0)
        appearance.colors.componentDivider = UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1.0)
        appearance.colors.text = UIColor(red: 51/255, green: 51/255, blue: 51/255, alpha: 1.0)
        appearance.colors.textSecondary = UIColor(red: 130/255, green: 130/255, blue: 130/255, alpha: 1.0)
        appearance.cornerRadius = 16
        configuration.appearance = appearance

        // Billing details
        configuration.billingDetailsCollectionConfiguration.name = .always
        configuration.billingDetailsCollectionConfiguration.email = .always
        configuration.billingDetailsCollectionConfiguration.phone = .always
        configuration.billingDetailsCollectionConfiguration.address = .full

        // Enable Apple Pay for subscriptions
        configuration.applePay = PaymentSheet.ApplePayConfiguration(
            merchantId: AppConfig.appleMerchantId,
            merchantCountryCode: "US"
        )

        // Step 3: Initialize Payment Sheet with subscription setup intent client secret
        // For subscriptions, the client secret is from the payment intent attached to the subscription
        let paymentSheet = PaymentSheet(
            paymentIntentClientSecret: clientSecret,
            configuration: configuration
        )

        // Get the topmost view controller
        guard let topViewController = UIApplication.shared.topViewController else {
            paymentErrorMessage = "Unable to present payment screen"
            showPaymentError = true
            return
        }

        // Present Payment Sheet and wait for result
        let result = await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                paymentSheet.present(from: topViewController) { result in
                    continuation.resume(returning: result)
                }
            }
        }

        // Step 4: Handle payment result
        switch result {
        case .completed:
            // Payment successful - update profile immediately (webhook is backup)
            await updateSubscriptionInProfile(tier: selectedTier, subscriptionId: subscriptionId)

            // Close modal and reset state
            showQuotaExceeded = false
            viewModel.quotaExceeded = false
            viewModel.quotaExceededReason = nil
            viewModel.errorMessage = nil

            // Reset subscription check flag so they can use the chat
            hasCheckedSubscription = false

        case .canceled:
            // User canceled - keep modal open so they can try again
            break

        case .failed(let error):
            // Payment failed - show error but keep modal open
            paymentErrorMessage = error.localizedDescription
            showPaymentError = true
        }
    }

    /// Updates the user's subscription info in Supabase after successful payment.
    /// This is the primary update path - webhook serves as backup/redundancy.
    private func updateSubscriptionInProfile(tier: SubscriptionTier, subscriptionId: String) async {
        do {
            guard let userId = supabase.auth.currentUser?.id else {
                print("❌ Failed to get user ID for subscription update")
                return
            }

            let tierValue = tier.rawValue
            let userIdString = userId.uuidString.lowercased()
            print("📝 Updating subscription for user: \(userIdString)")
            print("📝 - billing_plan: '\(tierValue)'")
            print("📝 - stripe_subscription_id: '\(subscriptionId)'")

            try await supabase.database
                .from("user_profiles")
                .update([
                    "billing_plan": tierValue,
                    "stripe_subscription_id": subscriptionId,
                    "subscription_status": "active",
                    "subscription_tier": tierValue
                ])
                .eq("id", value: userIdString)
                .execute()

            print("✅ Subscription updated successfully")
        } catch {
            print("❌ Error updating subscription: \(error)")
            // Non-fatal: webhook will eventually update it
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
                        .frame(width: 42, height: 42)
                        .background(CC.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(CC.border, lineWidth: 1)
                        )
                }

                Spacer()

                // New Chat button
                Button(action: {
                    Task {
                        await viewModel.startNewChat()
                    }
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(CC.primaryInk)
                        .frame(width: 42, height: 42)
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
            .padding(.vertical, 14)

            VStack(spacing: 3) {
                Text(viewModel.chatTitle)
                    .font(.custom("Manrope", size: 25))
                    .fontWeight(.heavy)
                    .foregroundColor(CC.text)

                Text(isOnline ? viewModel.chatSubtitle : "Offline")
                    .font(.custom("PlusJakartaSans-Regular", size: 11))
                    .foregroundColor(isOnline ? CC.primary : CC.muted)
            }
        }
        .padding(.top, 52)
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
                VStack(spacing: 18) {
                    if !viewModel.starterPrompts.isEmpty {
                        promptStarterRow
                    }

                    dateDivider

                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
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
                .padding(.bottom, 18)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(CC.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(CC.border, lineWidth: 1)
            )
            .padding(.top, 6)
    }

    private var disclaimer: some View {
        Text("AI can make mistakes. Always consult with a board-certified plastic surgeon for medical advice.")
            .font(.custom("PlusJakartaSans-Regular", size: 11))
            .foregroundColor(CC.muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
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
                .padding(.vertical, 10)
                .background(CC.bg)
            }

            HStack(alignment: .bottom, spacing: 12) {
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Image(systemName: "image")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(CC.primary)
                        .frame(width: 40, height: 40)
                        .background(CC.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                        .onChange(of: isTextFieldFocused) { _, isFocused in
                            if isFocused {
                                // User tapped in the input box - check subscription
                                Task {
                                    await checkSubscriptionStatus()
                                }
                            }
                        }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(CC.surface)
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(CC.border, lineWidth: 1)
                )

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 46, height: 46)
                        .background((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil) ? CC.cardStrong : CC.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil) || viewModel.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(CC.surface.opacity(0.92))
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
                    Text("Fast ways to ask")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                        .foregroundColor(CC.primaryInk)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(CC.primary)
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
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(CC.surface)
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
        .padding(15)
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
