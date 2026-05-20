//
//  ComparisonChatSheet.swift
//  Renaissance Mobile
//
//  AI chat sheet launched from WeekComparisonView. Pre-loads both journal entries'
//  metrics and notes as invisible context, and attaches a side-by-side composite
//  photo on the first message so Rena can analyze visual healing progress.
//

import SwiftUI

struct ComparisonChatSheet: View {
    let leftEntry: JournalEntry
    let rightEntry: JournalEntry
    let leftImage: UIImage?
    let rightImage: UIImage?

    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionStore.self) private var subscriptionStore

    @State private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var firstSendDone = false

    private let primary = Color(hex: "#6C63FF")
    private let ink     = Color(hex: "#2D2575")
    private let muted   = Color(hex: "#7B6FC0")
    private let pale    = Color(hex: "#9C93C8")
    private let soft    = Color(hex: "#EAE7FF")
    private let line    = Color(hex: "#D4CCFF")
    private let bg      = Color(hex: "#F8F8FF")

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().overlay(line)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                    .id(message.id)
                            }
                            if viewModel.isTyping {
                                HStack {
                                    TypingIndicatorView()
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 4)
                                    Spacer()
                                }
                                .id("typing")
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                    .onAppear { scrollProxy = proxy }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.isTyping) { _, isTyping in
                        if isTyping { scrollToBottom(proxy: proxy, target: "typing") }
                    }
                }

                inputBar
            }
        }
        .task {
            viewModel.injectComparisonContext(buildComparisonContext())
            await viewModel.initialize()
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            VStack(spacing: 2) {
                Text("Recovery Analysis")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                    .foregroundColor(ink)
                Text("\(shortLabel(leftEntry)) → \(shortLabel(rightEntry))")
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundColor(pale)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ink)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(line.opacity(0.5), lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 14)
        .background(Color.white)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(line)
            HStack(spacing: 10) {
                TextField("Ask about your progress…", text: $messageText, axis: .vertical)
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .foregroundColor(ink)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(line, lineWidth: 1))

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(canSend ? primary : pale)
                        .clipShape(Circle())
                }
                .disabled(!canSend)
                .animation(.easeOut(duration: 0.15), value: canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(bg)
        }
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isTyping
            && !viewModel.isLoading
    }

    // MARK: - Send

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""

        Task {
            // On the first send, attach a composite before/after image so Rena can analyze visuals.
            let imageData: Data? = firstSendDone ? nil : makeCompositeImageData()
            firstSendDone = true
            await viewModel.sendMessage(text, imageData: imageData)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, target: String? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.2)) {
                if let target {
                    proxy.scrollTo(target, anchor: .bottom)
                } else if let last = viewModel.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Context Builder

    private func buildComparisonContext() -> String {
        let hasPhotos = leftImage != nil && rightImage != nil
        let photosLine = hasPhotos
            ? "Photos for both days are attached — analyze any visible changes in swelling, bruising, redness, or overall appearance."
            : ""

        return """
        [Recovery comparison context — use this to answer questions about my healing progress. \
        Do not echo or list this back; let it inform your responses naturally.]

        BEFORE — \(fullLabel(leftEntry))
        \(metricsLine(leftEntry))
        \(notesLine(leftEntry))

        AFTER — \(fullLabel(rightEntry))
        \(metricsLine(rightEntry))
        \(notesLine(rightEntry))

        Change over \(daysDelta) days: \
        Swelling \(delta(leftEntry.swellingInt, rightEntry.swellingInt)), \
        Bruising \(delta(leftEntry.bruisingInt, rightEntry.bruisingInt)), \
        Redness \(delta(leftEntry.rednessInt, rightEntry.rednessInt)).
        \(photosLine)
        """
    }

    private func metricsLine(_ entry: JournalEntry) -> String {
        guard entry.hasRecoveryMetrics else { return "" }
        return "Swelling \(entry.swellingInt)/10, Bruising \(entry.bruisingInt)/10, Redness \(entry.rednessInt)/10."
    }

    private func notesLine(_ entry: JournalEntry) -> String {
        guard let notes = entry.notes, !notes.isEmpty else { return "" }
        return "Notes: \"\(notes)\""
    }

    private func delta(_ before: Int, _ after: Int) -> String {
        let diff = after - before
        if diff == 0 { return "unchanged" }
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }

    private var daysDelta: Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.day], from: leftEntry.entryDateAsDate, to: rightEntry.entryDateAsDate)
        return abs(comps.day ?? 0)
    }

    // MARK: - Composite Image

    private func makeCompositeImageData() -> Data? {
        guard let left = leftImage, let right = rightImage else { return nil }

        let targetHeight: CGFloat = 400
        let leftAspect = left.size.width / left.size.height
        let rightAspect = right.size.width / right.size.height
        let leftW = targetHeight * leftAspect
        let rightW = targetHeight * rightAspect
        let totalWidth = leftW + rightW

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: targetHeight))
        let composite = renderer.image { _ in
            left.draw(in: CGRect(x: 0, y: 0, width: leftW, height: targetHeight))
            right.draw(in: CGRect(x: leftW, y: 0, width: rightW, height: targetHeight))
        }

        return composite.jpegData(compressionQuality: 0.75)
    }

    // MARK: - Helpers

    private func shortLabel(_ entry: JournalEntry) -> String {
        "\(entry.dayLabel) · \(shortDate(entry.entryDateAsDate))"
    }

    private func fullLabel(_ entry: JournalEntry) -> String {
        return "\(entry.procedureName), \(entry.dayLabel) (\(shortDate(entry.entryDateAsDate)))"
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
