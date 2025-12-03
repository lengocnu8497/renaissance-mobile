//
//  ChatView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = ChatView.sampleMessages
    @State private var isTyping = true

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
            messageInput
        }
        .navigationBarHidden(true)
        .onAppear {
            handleInitialMessage()
        }
    }

    // MARK: - Initial Message Handler
    private func handleInitialMessage() {
        guard let initialMessage = initialMessage, !initialMessage.isEmpty else { return }

        // Auto-send the initial message as a user message bubble
        let userMessage = ChatMessage(
            text: initialMessage,
            isFromUser: true,
            timestamp: getCurrentTimestamp()
        )
        messages.append(userMessage)

        // Keep typing indicator showing (simulate concierge is responding)
        isTyping = true
    }

    private func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Date())
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
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                dateDivider

                ForEach(messages) { message in
                    MessageBubbleView(message: message)
                }

                if isTyping {
                    TypingIndicatorView()
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.Colors.backgroundChat)
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

    private var messageInput: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button(action: {}) {
                Image(systemName: "plus.circle")
                    .font(.system(size: Theme.IconSize.medium))
                    .foregroundColor(Theme.Colors.textChatSecondary)
            }

            HStack {
                TextField("Type your message...", text: $messageText)
                    .font(Theme.Typography.inputText)
                    .foregroundColor(Theme.Colors.textChatPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Theme.Colors.inputBackground)
            .cornerRadius(Theme.CornerRadius.xlarge)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.xlarge)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )

            Button(action: {}) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                    .frame(width: 48, height: 48)
                    .background(Theme.Colors.primaryChat)
                    .clipShape(Circle())
            }
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

    // MARK: - Sample Data
    static let sampleMessages = [
        ChatMessage(
            text: "Hello! Welcome to our cosmetic concierge service. How can I assist you today?",
            isFromUser: false,
            timestamp: "10:30 AM"
        ),
        ChatMessage(
            text: "Hi, I'm interested in learning more about non-invasive facial treatments.",
            isFromUser: true,
            timestamp: "10:31 AM"
        ),
        ChatMessage(
            text: "Of course. We have several options. Are you looking for something to address fine lines, skin texture, or perhaps skin tightening?",
            isFromUser: false,
            timestamp: "10:32 AM"
        )
    ]
}

#Preview {
    ChatView()
}
