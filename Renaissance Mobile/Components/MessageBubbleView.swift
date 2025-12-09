//
//  MessageBubbleView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
            if message.isFromUser {
                userMessage
            } else {
                conciergeMessage
            }
        }
    }

    // MARK: - User Message (Right Side)
    private var userMessage: some View {
        Group {
            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                timestampText(prefix: "You")

                VStack(alignment: .trailing, spacing: 8) {
                    // Display image if available
                    if let imageData = message.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: 200, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    }

                    // Display text if available
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(Theme.Typography.messageText)
                            .foregroundColor(.black)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(Theme.Colors.primaryChat)
                            .cornerRadius(Theme.CornerRadius.medium)
                            .cornerRadius(2, corners: [.bottomRight])
                    }
                }
            }
            .frame(maxWidth: 280, alignment: .trailing)

            avatarView(isUser: true)
        }
    }

    // MARK: - Concierge Message (Left Side)
    private var conciergeMessage: some View {
        Group {
            avatarView(isUser: false)

            VStack(alignment: .leading, spacing: 6) {
                timestampText(prefix: "Concierge")

                Text(message.text)
                    .font(Theme.Typography.messageText)
                    .foregroundColor(Theme.Colors.textChatPrimary)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.conciergeBubble)
                    .cornerRadius(Theme.CornerRadius.medium)
                    .cornerRadius(2, corners: [.bottomLeft])
            }
            .frame(maxWidth: 280, alignment: .leading)

            Spacer()
        }
    }

    // MARK: - Helper Views
    private func timestampText(prefix: String) -> some View {
        Text("\(prefix) • \(message.timestamp)")
            .font(Theme.Typography.timestamp)
            .foregroundColor(Theme.Colors.textChatSecondary)
    }

    private func avatarView(isUser: Bool) -> some View {
        Circle()
            .fill(isUser ? Color.gray.opacity(0.3) : Theme.Colors.primaryChat.opacity(0.3))
            .frame(width: Theme.IconSize.avatar, height: Theme.IconSize.avatar)
            .overlay(
                Image(systemName: isUser ? "person.fill" : "person.crop.circle.fill")
                    .font(.system(size: Theme.IconSize.small))
                    .foregroundColor(isUser ? .white : Theme.Colors.primaryChat)
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        MessageBubbleView(
            message: ChatMessage(
                text: "Hello! How can I help you today?",
                isFromUser: false,
                timestamp: "10:30 AM",
                responseId: nil
            )
        )

        MessageBubbleView(
            message: ChatMessage(
                text: "I'm interested in learning more about treatments.",
                isFromUser: true,
                timestamp: "10:31 AM",
                responseId: nil
            )
        )
    }
    .padding()
}
