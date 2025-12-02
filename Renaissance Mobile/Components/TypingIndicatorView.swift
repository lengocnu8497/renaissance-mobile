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
            typingDots
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

    private var typingDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .scaleEffect(1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: index
                    )
            }
        }
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
