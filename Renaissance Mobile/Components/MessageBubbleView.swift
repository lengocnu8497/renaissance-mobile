//
//  MessageBubbleView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

private enum ChatBubbleStyle {
    static let assistantSurface = Color.white
    static let assistantCard    = Color(hex: "#EAE7FF")
    static let assistantBorder  = Color(hex: "#6C63FF").opacity(0.08)
    static let userBubble       = Color(hex: "#6C63FF")
    static let text             = Color(hex: "#1E1B4B")
    static let muted            = Color(hex: "#7B6FC0")
    static let primaryInk       = Color(hex: "#2D2575")
    static let accent            = Color(hex: "#6C63FF")
    static let accentSoft        = Color(hex: "#EAE7FF")
    static let cardStrong        = Color(hex: "#E0DBFF")
    static let shadow            = Color(hex: "#6C63FF").opacity(0.08)
}

struct MessageBubbleView: View {
    let message: ChatMessage
    var onUnlockTap: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.isFromUser {
                userMessage
            } else {
                conciergeMessage
            }
        }
    }

    private var userMessage: some View {
        Group {
            Spacer(minLength: 36)

            VStack(alignment: .trailing, spacing: 6) {
                timestampText(prefix: "You", isLeading: false)

                VStack(alignment: .trailing, spacing: 10) {
                    if let imageData = message.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: 224, maxHeight: 224)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }

                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.custom("PlusJakartaSans-Regular", size: 14))
                            .foregroundColor(.white)
                            .lineSpacing(6)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .fill(ChatBubbleStyle.userBubble)
                            )
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 26,
                                    bottomLeadingRadius: 26,
                                    bottomTrailingRadius: 10,
                                    topTrailingRadius: 26
                                )
                            )
                    }
                }
            }
            .frame(maxWidth: 292, alignment: .trailing)
        }
    }

    private var conciergeMessage: some View {
        Group {
            RenaissanceAgentAvatar(size: 34)

            VStack(alignment: .leading, spacing: 6) {
                timestampText(prefix: "Rena", isLeading: true)

                VStack(alignment: .leading, spacing: 10) {
                    if !message.text.isEmpty {
                        if isConsultationPrepResponse {
                            ConsultationPrepCardBubble(text: message.text)
                        } else if message.isLockedPreview {
                            LockedPreviewBubble(
                                title: message.lockedPreviewTitle ?? "Rena drafted an answer",
                                text: message.text,
                                onUnlockTap: onUnlockTap
                            )
                        } else if isTimelineResponse {
                            TimelineCardBubble(text: message.text)
                        } else {
                            Text(message.text)
                                .font(.custom("PlusJakartaSans-Regular", size: 14))
                                .foregroundColor(ChatBubbleStyle.text)
                                .lineSpacing(6)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .fill(ChatBubbleStyle.assistantSurface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                                .stroke(ChatBubbleStyle.assistantBorder, lineWidth: 1)
                                        )
                                        .shadow(color: ChatBubbleStyle.shadow, radius: 12, x: 0, y: 3)
                                )
                                .clipShape(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 26,
                                        bottomLeadingRadius: 10,
                                        bottomTrailingRadius: 26,
                                        topTrailingRadius: 26
                                    )
                                )
                        }
                    }

                    if let imageUrlString = message.generatedImageUrl,
                       let url = URL(string: imageUrlString) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 252, maxHeight: 252)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(ChatBubbleStyle.assistantCard)
                                .frame(width: 210, height: 210)
                                .overlay(ProgressView().tint(ChatBubbleStyle.primaryInk))
                        }
                    }
                }
            }
            .frame(maxWidth: 304, alignment: .leading)

            Spacer(minLength: 18)
        }
    }

    private var isConsultationPrepResponse: Bool {
        let t = message.text
        return !message.isFromUser && (
            t.contains("Questions to Ask") ||
            t.contains("Proactively Disclose") ||
            t.contains("What to Look For") ||
            (t.contains("1)") && t.contains("2)") && t.contains("surgeon"))
        )
    }

    var isTimelineResponse: Bool {
        guard !message.isFromUser else { return false }
        let t = message.text
        let weekHits = ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5", "Week 6", "Week 7", "Week 8"]
            .filter { t.contains($0) }.count
        let phaseHits = ["Phase 1", "Phase 2", "Phase 3"].filter { t.contains($0) }.count
        let dayHits = t.contains("Day 1") && (t.contains("Day 7") || t.contains("Day 14") || t.contains("Week 2"))
        return weekHits >= 2 || phaseHits >= 2 || dayHits
    }

    private func timestampText(prefix: String, isLeading: Bool) -> some View {
        Text("\(prefix) • \(message.timestamp)")
            .font(.custom("PlusJakartaSans-SemiBold", size: 10))
            .foregroundColor(ChatBubbleStyle.muted)
            .frame(maxWidth: .infinity, alignment: isLeading ? .leading : .trailing)
    }
}

private struct LockedPreviewBubble: View {
    let title: String
    let text: String
    var onUnlockTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(ChatBubbleStyle.accent)
                    .frame(width: 24, height: 24)
                    .background(ChatBubbleStyle.accentSoft)
                    .clipShape(Circle())

                Text(title.uppercased())
                    .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                    .tracking(2)
                    .foregroundColor(ChatBubbleStyle.accent)
            }

            ZStack {
                Text(text)
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .foregroundColor(ChatBubbleStyle.text)
                    .lineSpacing(6)
                    .blur(radius: 6)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: 10) {
                    Text("Unlock this answer")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                        .foregroundColor(ChatBubbleStyle.primaryInk)

                    Text("Subscribe to reveal Rena's personalized response and continue the conversation.")
                        .font(.custom("PlusJakartaSans-Regular", size: 12))
                        .foregroundColor(ChatBubbleStyle.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    Button(action: { onUnlockTap?() }) {
                        Text("Unlock with Subscription")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(ChatBubbleStyle.primaryInk)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(ChatBubbleStyle.assistantSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(ChatBubbleStyle.assistantBorder, lineWidth: 1)
                )
                .shadow(color: ChatBubbleStyle.shadow, radius: 12, x: 0, y: 3)
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 26,
                bottomLeadingRadius: 10,
                bottomTrailingRadius: 26,
                topTrailingRadius: 26
            )
        )
    }
}

private struct TimelineCardBubble: View {
    let text: String

    private struct TimelineItem {
        let phase: String
        let title: String
        let bullets: [String]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                RenaissanceAgentAvatar(size: 24)
                Text("RECOVERY TIMELINE")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                    .tracking(2.3)
                    .foregroundColor(ChatBubbleStyle.accent)
            }

            let items = parseItems(text)
            if !items.isEmpty {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    timelineRow(item: item, isLast: index == items.count - 1)
                }
            } else {
                Text(text)
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundColor(ChatBubbleStyle.text)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(ChatBubbleStyle.accentSoft.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(ChatBubbleStyle.accent.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private func timelineRow(item: TimelineItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(ChatBubbleStyle.accent)
                    .frame(width: 7, height: 7)
                    .padding(.top, 5)
                if !isLast {
                    Rectangle()
                        .fill(ChatBubbleStyle.accent.opacity(0.2))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.phase.uppercased())
                    .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                    .tracking(1.5)
                    .foregroundColor(ChatBubbleStyle.accent)

                if !item.title.isEmpty {
                    Text(item.title)
                        .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                        .foregroundColor(ChatBubbleStyle.primaryInk)
                }

                ForEach(item.bullets.prefix(4), id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(ChatBubbleStyle.accent.opacity(0.45))
                            .frame(width: 3.5, height: 3.5)
                            .padding(.top, 5.5)
                        Text(bullet)
                            .font(.custom("PlusJakartaSans-Regular", size: 12))
                            .foregroundColor(ChatBubbleStyle.text)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.bottom, isLast ? 0 : 12)
        }
    }

    private func parseItems(_ text: String) -> [TimelineItem] {
        var items: [TimelineItem] = []
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let phaseStarters = ["Week ", "Phase ", "Day ", "Month ", "Stage "]

        var currentPhase = ""
        var currentTitle = ""
        var currentBullets: [String] = []

        func flush() {
            guard !currentPhase.isEmpty else { return }
            items.append(TimelineItem(phase: currentPhase, title: currentTitle, bullets: currentBullets))
        }

        for line in lines {
            guard !line.isEmpty else { continue }
            let cleanLine = line
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "### ", with: "")
                .replacingOccurrences(of: "## ", with: "")
                .trimmingCharacters(in: .whitespaces)

            let isHeader = phaseStarters.contains(where: { cleanLine.hasPrefix($0) }) && cleanLine.count < 70

            if isHeader {
                flush()
                if let colonIdx = cleanLine.firstIndex(of: ":") {
                    currentPhase = String(cleanLine[cleanLine.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
                    currentTitle = String(cleanLine[cleanLine.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                } else {
                    currentPhase = cleanLine
                    currentTitle = ""
                }
                currentBullets = []
            } else if cleanLine.hasPrefix("- ") || cleanLine.hasPrefix("• ") {
                let bullet = String(cleanLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !bullet.isEmpty { currentBullets.append(bullet) }
            } else if cleanLine.hasPrefix("* ") {
                let bullet = String(cleanLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !bullet.isEmpty { currentBullets.append(bullet) }
            }
        }

        flush()
        return items
    }
}

struct RenaissanceAgentAvatar: View {
    var size: CGFloat = 34

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "#9C95F0"),
                        Color(hex: "#7B73F5"),
                        Color(hex: "#6C63FF")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(concentricCirclesIcon)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
            )
    }

    private var concentricCirclesIcon: some View {
        Canvas { context, size in
            let ring = Color.white.opacity(0.65)
            let ringInner = Color.white.opacity(0.9)
            let s = size.width / 80
            let cx = size.width / 2
            let cy = size.height / 2

            var outer = Path()
            outer.addEllipse(in: CGRect(x: cx - 38*s, y: cy - 38*s, width: 76*s, height: 76*s))
            context.stroke(outer, with: .color(ring), lineWidth: 1.35)

            var middle = Path()
            middle.addEllipse(in: CGRect(x: cx - 28*s, y: cy - 28*s, width: 56*s, height: 56*s))
            context.stroke(middle, with: .color(ring), lineWidth: 1.1)

            var inner = Path()
            inner.addEllipse(in: CGRect(x: cx - 18*s, y: cy - 18*s, width: 36*s, height: 36*s))
            context.stroke(inner, with: .color(ringInner), lineWidth: 1.35)

            var dot = Path()
            dot.addEllipse(in: CGRect(x: cx - 4*s, y: cy - 4*s, width: 8*s, height: 8*s))
            context.fill(dot, with: .color(ringInner))
        }
    }
}

struct ConsultationPrepCardBubble: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                RenaissanceAgentAvatar(size: 24)
                Text("CONSULTATION PREP")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                    .tracking(2.3)
                    .foregroundColor(ChatBubbleStyle.accent)
            }

            let sections = parseConsultationSections(text)
            if !sections.isEmpty {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    consultationSection(title: section.title, bullets: section.bullets)
                }
            } else {
                Text(text)
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundColor(ChatBubbleStyle.text)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(ChatBubbleStyle.accentSoft.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(ChatBubbleStyle.accent.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private func consultationSection(title: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                .tracking(2)
                .foregroundColor(ChatBubbleStyle.accent)

            ForEach(bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(ChatBubbleStyle.accent)
                        .frame(width: 4, height: 4)
                        .padding(.top, 7)

                    Text(bullet)
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundColor(ChatBubbleStyle.text)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private struct ConsultationSection {
        let title: String
        let bullets: [String]
    }

    private func parseConsultationSections(_ text: String) -> [ConsultationSection] {
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
                cleanLine.count < 88

            if isSectionHeader {
                if !currentTitle.isEmpty {
                    sections.append(ConsultationSection(title: currentTitle, bullets: currentBullets))
                }
                currentTitle = cleanLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
                currentBullets = []
            } else if cleanLine.hasPrefix("-") || cleanLine.hasPrefix("•") || cleanLine.hasPrefix("*") {
                let bullet = String(cleanLine.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !bullet.isEmpty { currentBullets.append(bullet) }
            } else if !currentTitle.isEmpty {
                currentBullets.append(cleanLine)
            }
        }

        if !currentTitle.isEmpty {
            sections.append(ConsultationSection(title: currentTitle, bullets: currentBullets))
        }

        return sections
    }
}

struct ConsultationPrepOfferCard: View {
    let procedureName: String
    let onAccept: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RenaissanceAgentAvatar(size: 32)

            VStack(alignment: .leading, spacing: 10) {
                Text("Would you like me to prepare a consultation guide for \(procedureName)?")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                    .foregroundColor(ChatBubbleStyle.primaryInk)
                    .lineSpacing(3)

                Text("I can turn this into questions to ask, things to disclose, and what to look for in a provider.")
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundColor(ChatBubbleStyle.muted)
                    .lineSpacing(3)

                Button(action: onAccept) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Prepare guide")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(ChatBubbleStyle.primaryInk)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(ChatBubbleStyle.assistantSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(ChatBubbleStyle.assistantBorder, lineWidth: 1)
                    )
            )
        }
        .padding(.leading, 2)
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
    .background(Color(hex: "#FAFAFF"))
}
