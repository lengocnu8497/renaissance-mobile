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
                    if !message.text.isEmpty {
                        if isConsultationPrepResponse {
                            ConsultationPrepCardBubble(text: message.text)
                        } else {
                            Text(message.text)
                                .font(Theme.Typography.messageText)
                                .foregroundColor(Theme.Colors.textChatPrimary)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .padding(.vertical, Theme.Spacing.md)
                                .background(Theme.Colors.conciergeBubble)
                                .cornerRadius(Theme.CornerRadius.medium)
                                .cornerRadius(2, corners: [.bottomLeft])
                        }
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
            .frame(maxWidth: 300, alignment: .leading)

            Spacer()
        }
    }

    // Detect if this is a Consultation Prep response by looking for the section headers
    private var isConsultationPrepResponse: Bool {
        let t = message.text
        return !message.isFromUser && (
            t.contains("Questions to Ask") ||
            t.contains("Proactively Disclose") ||
            t.contains("What to Look For") ||
            (t.contains("1)") && t.contains("2)") && t.contains("surgeon"))
        )
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

// MARK: - Consultation Prep Card Bubble
// Matches the "rena-card" style from renaesthetic.com landing page:
// rgba(196,146,154,0.07) bg, rgba(196,146,154,0.22) border, uppercase dusty rose label

struct ConsultationPrepCardBubble: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header label
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#C4929A"))
                Text("CONSULTATION PREP")
                    .font(.custom("Outfit-SemiBold", size: 9))
                    .tracking(2.5)
                    .foregroundColor(Color(hex: "#C4929A"))
            }

            // Parse sections from AI response text
            let sections = parseConsultationSections(text)
            if !sections.isEmpty {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    consultationSection(title: section.title, bullets: section.bullets)
                }
            } else {
                // Fallback: render raw text
                Text(text)
                    .font(.custom("Outfit-Light", size: 13))
                    .foregroundColor(Color(hex: "#3D2B2E"))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color(hex: "#C4929A").opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#C4929A").opacity(0.22), lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private func consultationSection(title: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.custom("Outfit-SemiBold", size: 9))
                .tracking(2)
                .foregroundColor(Color(hex: "#C4929A"))
                .padding(.bottom, 2)

            ForEach(bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 8) {
                    Text("·")
                        .font(.custom("Outfit-SemiBold", size: 16))
                        .foregroundColor(Color(hex: "#C4929A"))
                        .frame(width: 10)
                        .offset(y: -2)
                    Text(bullet)
                        .font(.custom("Outfit-Light", size: 13))
                        .foregroundColor(Color(hex: "#3D2B2E"))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 4)
    }

    private struct ConsultationSection {
        let title: String
        let bullets: [String]
    }

    private func parseConsultationSections(_ text: String) -> [ConsultationSection] {
        // Try to split on numbered sections like "1)" or "**1."
        var sections: [ConsultationSection] = []
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }

        var currentTitle = ""
        var currentBullets: [String] = []

        let sectionStarters = ["1)", "2)", "3)", "1.", "2.", "3."]

        for line in lines {
            guard !line.isEmpty else { continue }

            let cleanLine = line
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "##", with: "")
                .trimmingCharacters(in: .whitespaces)

            let isSectionHeader = sectionStarters.contains(where: { cleanLine.hasPrefix($0) }) &&
                cleanLine.count < 80

            if isSectionHeader {
                if !currentTitle.isEmpty {
                    sections.append(ConsultationSection(title: currentTitle, bullets: currentBullets))
                }
                // Extract title after the number
                let title = cleanLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
                currentTitle = title
                currentBullets = []
            } else if cleanLine.hasPrefix("-") || cleanLine.hasPrefix("•") || cleanLine.hasPrefix("*") {
                let bullet = String(cleanLine.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !bullet.isEmpty { currentBullets.append(bullet) }
            } else if !currentTitle.isEmpty && !cleanLine.isEmpty {
                // Plain line under a section — treat as bullet
                currentBullets.append(cleanLine)
            }
        }

        if !currentTitle.isEmpty {
            sections.append(ConsultationSection(title: currentTitle, bullets: currentBullets))
        }

        return sections
    }
}

// MARK: - Consultation Prep Offer Card (injected into chat)

struct ConsultationPrepOfferCard: View {
    let procedureName: String
    let onAccept: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Small avatar placeholder
            Circle()
                .fill(Color(hex: "#C4929A").opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "checklist")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#C4929A"))
                )

            VStack(alignment: .leading, spacing: 10) {
                Text("Would you like me to prepare a **Consultation Prep** for \(procedureName)?")
                    .font(.custom("Outfit-Light", size: 14))
                    .foregroundColor(Color(hex: "#3D2B2E"))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text("I'll give you personalized questions to ask, things to disclose, and what to look for in a provider.")
                    .font(.custom("Outfit-Light", size: 12))
                    .foregroundColor(Color(hex: "#B8A9AB"))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onAccept) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                        Text("Yes, prepare my consultation guide")
                            .font(.custom("Outfit-SemiBold", size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#6B3346"), Color(hex: "#8E4C5C")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: Color(hex: "#8E4C5C").opacity(0.28), radius: 6, x: 0, y: 3)
                }
            }
            .padding(14)
            .background(Color(hex: "#C4929A").opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#C4929A").opacity(0.22), lineWidth: 1))
            .cornerRadius(16)
        }
        .padding(.leading, 4)
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
