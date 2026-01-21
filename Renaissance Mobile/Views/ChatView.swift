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
    @State private var showPaymentError = false
    @State private var paymentErrorMessage = ""
    @State private var hasCheckedSubscription = false
    @FocusState private var isTextFieldFocused: Bool

    var initialMessage: String?
    var onBackButtonTapped: (() -> Void)?

    init(initialMessage: String? = nil, onBackButtonTapped: (() -> Void)? = nil) {
        self.initialMessage = initialMessage
        self.onBackButtonTapped = onBackButtonTapped
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            messagesList
            disclaimer
            messageInput
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showQuotaExceeded) {
            QuotaExceededView(
                reason: viewModel.quotaExceededReason ?? "You've exceeded your quota",
                onUpgrade: { tier in
                    await handleUpgrade(tier: tier)
                },
                onDismiss: {
                    showQuotaExceeded = false
                    hasCheckedSubscription = false  // Reset so it checks again next time
                    viewModel.quotaExceeded = false  // Reset quota exceeded state so onChange can trigger again
                    viewModel.quotaExceededReason = nil
                    viewModel.errorMessage = nil
                }
            )
            .interactiveDismissDisabled()
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
            handleInitialMessage()
        }
    }

    // MARK: - Initial Message Handler
    private func handleInitialMessage() {
        guard let initialMessage = initialMessage, !initialMessage.isEmpty else { return }

        // Auto-send the initial message through the ViewModel
        Task {
            await viewModel.sendMessage(initialMessage)
        }
    }

    // MARK: - Actions
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || selectedImageData != nil else { return }

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
            guard let userId = try? await supabase.auth.session.user.id else {
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
            priceId = EnvironmentConfig.stripeSilverPriceId
        case .gold:
            priceId = EnvironmentConfig.stripeGoldPriceId
        }

        // Validate price ID is configured
        guard !priceId.contains("REPLACE_WITH_YOUR") else {
            paymentErrorMessage = "Subscription plan not configured. Please add Stripe price IDs to EnvironmentConfig."
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

        // Appearance customization
        var appearance = PaymentSheet.Appearance()
        appearance.colors.primary = UIColor(red: 208/255, green: 187/255, blue: 149/255, alpha: 1.0)
        appearance.colors.background = UIColor(red: 247/255, green: 247/255, blue: 246/255, alpha: 1.0)
        appearance.cornerRadius = 16
        configuration.appearance = appearance

        // Billing details
        configuration.billingDetailsCollectionConfiguration.name = .always
        configuration.billingDetailsCollectionConfiguration.email = .always
        configuration.billingDetailsCollectionConfiguration.phone = .always
        configuration.billingDetailsCollectionConfiguration.address = .full

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
            guard let userId = try? await supabase.auth.session.user.id else {
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
        VStack(spacing: Theme.Spacing.xs) {
            HStack {
                Button(action: {
                    if let onBackButtonTapped = onBackButtonTapped {
                        onBackButtonTapped()
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Theme.Colors.textChatPrimary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("Your Concierge")
                        .font(Theme.Typography.chatHeader)
                        .foregroundColor(Theme.Colors.textChatPrimary)

                    Text("Online")
                        .font(Theme.Typography.statusText)
                        .foregroundColor(Theme.Colors.online)
                }

                Spacer()

                // Spacer for symmetry
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(Theme.Colors.backgroundChat)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .bottom
        )
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    dateDivider

                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    if viewModel.isTyping {
                        TypingIndicatorView()
                            .id("typing")
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
                .onChange(of: viewModel.messages.count) { _, _ in
                    // Auto-scroll to the latest message
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isTyping) { _, isTyping in
                    // Auto-scroll when typing indicator appears
                    if isTyping {
                        withAnimation {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }
            .background(Theme.Colors.backgroundChat)
        }
    }

    private var dateDivider: some View {
        Text("Today")
            .font(Theme.Typography.dateDivider)
            .foregroundColor(Theme.Colors.textChatSecondary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(Theme.CornerRadius.medium)
            .padding(.top, Theme.Spacing.lg)
    }

    private var disclaimer: some View {
        Text("AI can make mistakes. Always consult with a board-certified plastic surgeon for medical advice.")
            .font(.caption2)
            .foregroundColor(Theme.Colors.textChatSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.backgroundChat)
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
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
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
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.backgroundChat)
            }

            HStack(spacing: Theme.Spacing.md) {
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: Theme.IconSize.medium))
                        .foregroundColor(Theme.Colors.textChatSecondary)
                }
                .onChange(of: selectedImage) { _, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                        }
                    }
                }

                HStack {
                    TextField("Type your message...", text: $messageText)
                        .font(Theme.Typography.inputText)
                        .foregroundColor(Theme.Colors.textChatPrimary)
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
                .background(Theme.Colors.inputBackground)
                .cornerRadius(Theme.CornerRadius.xlarge)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.xlarge)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                        .frame(width: 48, height: 48)
                        .background((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil) ? Color.gray.opacity(0.3) : Theme.Colors.primaryChat)
                        .clipShape(Circle())
                }
                .disabled((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil) || viewModel.isLoading)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.backgroundChat)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.2)),
                alignment: .top
            )
        }
    }

}

#Preview {
    ChatView()
}
