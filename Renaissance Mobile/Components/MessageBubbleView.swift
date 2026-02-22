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
                            .foregroundColor(.white)
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

                VStack(alignment: .leading, spacing: 8) {
                    // Display text if available
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(Theme.Typography.messageText)
                            .foregroundColor(Theme.Colors.textChatPrimary)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(Theme.Colors.conciergeBubble)
                            .cornerRadius(Theme.CornerRadius.medium)
                            .cornerRadius(2, corners: [.bottomLeft])
                    }

                    // Display AI-generated image if available
                    if let imageUrlString = message.generatedImageUrl,
                       let url = URL(string: imageUrlString) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 250, maxHeight: 250)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                        } placeholder: {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                .fill(Theme.Colors.iconCircleBackground)
                                .frame(width: 200, height: 200)
                                .overlay(
                                    ProgressView()
                                        .tint(Theme.Colors.primaryChat)
                                )
                        }
                    }
                }
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
        Group {
            if isUser {
                Circle()
                    .fill(Theme.Colors.iconCircleBackground)
                    .frame(width: Theme.IconSize.avatar, height: Theme.IconSize.avatar)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: Theme.IconSize.small))
                            .foregroundColor(Theme.Colors.primaryChat)
                    )
            } else {
                concentricCirclesAvatar
                    .frame(width: Theme.IconSize.avatar, height: Theme.IconSize.avatar)
            }
        }
    }

    private var concentricCirclesAvatar: some View {
        let dustyRose = Color(red: 196/255, green: 146/255, blue: 154/255)
        let mauveberry = Color(red: 142/255, green: 76/255, blue: 92/255)

        return Canvas { context, size in
            let s = size.width / 80
            let cx = size.width / 2
            let cy = size.height / 2

            var outer = Path()
            outer.addEllipse(in: CGRect(x: cx - 38*s, y: cy - 38*s, width: 76*s, height: 76*s))
            context.stroke(outer, with: .color(dustyRose), lineWidth: 1.5)

            var middle = Path()
            middle.addEllipse(in: CGRect(x: cx - 28*s, y: cy - 28*s, width: 56*s, height: 56*s))
            context.stroke(middle, with: .color(dustyRose), lineWidth: 1.2)

            var inner = Path()
            inner.addEllipse(in: CGRect(x: cx - 18*s, y: cy - 18*s, width: 36*s, height: 36*s))
            context.stroke(inner, with: .color(mauveberry), lineWidth: 1.5)

            var arc = Path()
            arc.move(to: CGPoint(x: 40*s, y: 26*s))
            arc.addCurve(
                to: CGPoint(x: 54*s, y: 40*s),
                control1: CGPoint(x: 48*s, y: 26*s),
                control2: CGPoint(x: 54*s, y: 32*s)
            )
            arc.addCurve(
                to: CGPoint(x: 40*s, y: 54*s),
                control1: CGPoint(x: 54*s, y: 48*s),
                control2: CGPoint(x: 48*s, y: 54*s)
            )
            context.stroke(arc, with: .color(dustyRose), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

            var dot = Path()
            dot.addEllipse(in: CGRect(x: cx - 4*s, y: cy - 4*s, width: 8*s, height: 8*s))
            context.fill(dot, with: .color(dustyRose))
        }
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
