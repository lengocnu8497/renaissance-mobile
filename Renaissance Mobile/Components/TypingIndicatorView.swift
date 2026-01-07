//
//  TypingIndicatorView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct TypingIndicatorView: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
            avatarView
            thinkingBubble
            Spacer()
        }
    }

    // MARK: - Subviews
    private var avatarView: some View {
        Circle()
            .fill(Theme.Colors.primaryChat.opacity(0.3))
            .frame(width: Theme.IconSize.avatar, height: Theme.IconSize.avatar)
            .overlay(
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: Theme.IconSize.small))
                    .foregroundColor(Theme.Colors.primaryChat)
            )
    }

    private var thinkingBubble: some View {
        Text("Thinking...")
            .font(Theme.Typography.messageText)
            .foregroundColor(Theme.Colors.textChatSecondary)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 14)
            .background(Theme.Colors.conciergeBubble)
            .cornerRadius(Theme.CornerRadius.medium)
            .cornerRadius(2, corners: [.bottomLeft])
    }
}

#Preview {
    TypingIndicatorView()
        .padding()
}
