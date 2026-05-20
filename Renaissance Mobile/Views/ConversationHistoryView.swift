//
//  ConversationHistoryView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 5/16/26.
//

import SwiftUI

struct ConversationHistoryView: View {
    var onSelectConversation: (UUID) -> Void
    var onNewConversation: () -> Void
    var onDismiss: () -> Void

    @State private var conversations: [ChatConversation] = []
    @State private var searchQuery = ""
    @State private var isLoading = false

    private let db = ChatDatabaseService(supabase: supabase)

    // MARK: - Computed

    private var filteredConversations: [ChatConversation] {
        guard !searchQuery.isEmpty else { return conversations }
        let q = searchQuery.lowercased()
        return conversations.filter {
            ($0.title ?? "").lowercased().contains(q) ||
            ($0.lastPreview ?? "").lowercased().contains(q)
        }
    }

    private var pinnedConversations: [ChatConversation] {
        filteredConversations.filter { $0.isPinned }
    }

    private var recentConversations: [ChatConversation] {
        filteredConversations.filter { !$0.isPinned }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "#FAFAFF").ignoresSafeArea()

            VStack(spacing: 0) {
                historyHeader
                searchBar

                if isLoading && conversations.isEmpty {
                    Spacer()
                    ProgressView().tint(Color(hex: "#6C63FF"))
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            if !pinnedConversations.isEmpty {
                                pinnedSection
                            }
                            recentSection
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .task { await loadConversations() }
    }

    // MARK: - Header

    private var historyHeader: some View {
        ZStack {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#2D2575"))
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "#E0DBFF").opacity(0.8), lineWidth: 1)
                        )
                }

                Spacer()

                Button(action: onNewConversation) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "#6C63FF"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color(hex: "#6C63FF").opacity(0.35), radius: 8, x: 0, y: 3)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 14)

            Text("Ask Rena")
                .font(.custom("Outfit-Bold", size: 17))
                .foregroundColor(Color(hex: "#2D2575"))
        }
        .padding(.top, 38)
        .background(Color(hex: "#FAFAFF"))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(hex: "#E0DBFF").opacity(0.8))
                .frame(height: 1)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#8B7FF0"))
            TextField("Search conversations...", text: $searchQuery)
                .font(.custom("Outfit-Light", size: 13))
                .foregroundColor(Color(hex: "#1E1B4B"))
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(hex: "#EEEEFF"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "#FAFAFF"))
    }

    // MARK: - Pinned Section

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Pinned")
                .padding(.horizontal, 18)

            ForEach(pinnedConversations) { conv in
                pinnedCard(conv)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 16)
    }

    private func pinnedCard(_ conv: ChatConversation) -> some View {
        Button {
            markSeen(conv.id)
            onSelectConversation(conv.id)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 36, height: 36)
                        .shadow(color: Color(hex: "#6C63FF").opacity(0.15), radius: 6, x: 0, y: 2)
                    Image(systemName: topicIcon(for: conv.title))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#8B7FF0"))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(conv.title ?? "Conversation")
                        .font(.custom("Outfit-Bold", size: 13))
                        .foregroundColor(Color(hex: "#1E1B4B"))
                        .lineLimit(1)

                    if let preview = conv.lastPreview, !preview.isEmpty {
                        Text(preview)
                            .font(.custom("Outfit-Light", size: 11.5))
                            .foregroundColor(Color(hex: "#7B6FC0"))
                            .lineLimit(2)
                            .lineSpacing(1.2)
                    }

                    Text(metaLine(conv))
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#8B7FF0"))
                        .padding(.top, 3)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#EAE7FF"), Color(hex: "#E0DBFF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { togglePin(conv) } label: {
                Label("Unpin", systemImage: "pin.slash.fill")
            }
            Button(role: .destructive) { archive(conv) } label: {
                Label("Archive", systemImage: "archivebox")
            }
        }
    }

    // MARK: - Recent Section

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !recentConversations.isEmpty || pinnedConversations.isEmpty {
                sectionLabel(searchQuery.isEmpty ? "Recent" : "Results")
                    .padding(.horizontal, 18)
            }

            if conversations.isEmpty && !isLoading {
                emptyState
            } else {
                VStack(spacing: 6) {
                    ForEach(recentConversations) { conv in
                        threadRow(conv)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func threadRow(_ conv: ChatConversation) -> some View {
        Button {
            markSeen(conv.id)
            onSelectConversation(conv.id)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(hex: "#EAE7FF"))
                        .frame(width: 32, height: 32)
                    Image(systemName: topicIcon(for: conv.title))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#6C63FF"))
                }
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(conv.title ?? "Conversation")
                        .font(.custom("Outfit-SemiBold", size: 13))
                        .foregroundColor(Color(hex: "#1E1B4B"))
                        .lineLimit(1)

                    if let preview = conv.lastPreview, !preview.isEmpty {
                        Text(preview)
                            .font(.custom("Outfit-Light", size: 11))
                            .foregroundColor(Color(hex: "#7B6FC0"))
                            .lineLimit(1)
                    }

                    Text(metaLine(conv))
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#8B7FF0"))
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)

                if isUnread(conv) {
                    Circle()
                        .fill(Color(hex: "#6C63FF"))
                        .frame(width: 8, height: 8)
                        .padding(.trailing, 2)
                        .padding(.top, 1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color(hex: "#6C63FF").opacity(0.05), radius: 6, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { togglePin(conv) } label: {
                Label("Pin", systemImage: "pin.fill")
            }
            Button(role: .destructive) { archive(conv) } label: {
                Label("Archive", systemImage: "archivebox")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "#8B7FF0").opacity(0.35))
                .padding(.bottom, 4)
            Text("No conversations yet")
                .font(.custom("Outfit-SemiBold", size: 15))
                .foregroundColor(Color(hex: "#7B6FC0"))
            Text("Tap + to start chatting with Rena")
                .font(.custom("Outfit-Light", size: 13))
                .foregroundColor(Color(hex: "#7B6FC0").opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 64)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.custom("Outfit-SemiBold", size: 10))
            .foregroundColor(Color(hex: "#7B6FC0"))
            .tracking(1.5)
            .textCase(.uppercase)
            .padding(.leading, 2)
    }

    private func metaLine(_ conv: ChatConversation) -> String {
        let date = relativeDate(conv.updatedAt)
        if let count = conv.storedMessageCount, count > 0 {
            return "\(date) · \(count) message\(count == 1 ? "" : "s")"
        }
        return date
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        let now = Date()
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: date),
            to: cal.startOfDay(for: now)
        ).day ?? 0
        if days < 7 { return "\(days) days ago" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }

    private func topicIcon(for title: String?) -> String {
        let t = (title ?? "").lowercased()
        if t.contains("question") || t.contains("consult") || t.contains("surgeon") || t.contains("provider") {
            return "questionmark.bubble"
        }
        if t.contains("diet") || t.contains("food") || t.contains("supplement") || t.contains("nutrition") {
            return "fork.knife"
        }
        if t.contains("swell") || t.contains("timeline") || t.contains("recovery") || t.contains("schedule") {
            return "chart.line.uptrend.xyaxis"
        }
        if t.contains("pain") || t.contains("medication") || t.contains("care") || t.contains("heal") {
            return "cross.case"
        }
        if t.contains("photo") || t.contains("image") || t.contains("picture") || t.contains("look") {
            return "camera"
        }
        if t.contains("prep") || t.contains("before") || t.contains("guide") || t.contains("checklist") {
            return "list.bullet.clipboard"
        }
        return "bubble.left"
    }

    private func isUnread(_ conv: ChatConversation) -> Bool {
        let key = "rena.conv_seen.\(conv.id.uuidString)"
        guard let lastSeen = UserDefaults.standard.object(forKey: key) as? Date else { return false }
        return conv.updatedAt > lastSeen
    }

    private func markSeen(_ id: UUID) {
        UserDefaults.standard.set(Date(), forKey: "rena.conv_seen.\(id.uuidString)")
    }

    private func togglePin(_ conv: ChatConversation) {
        guard let idx = conversations.firstIndex(where: { $0.id == conv.id }) else { return }
        var updated = conv
        var meta = updated.metadata ?? [:]
        meta["is_pinned"] = AnyCodable(!conv.isPinned)
        updated.metadata = meta
        conversations[idx] = updated
        Task { try? await db.updateConversation(updated) }
    }

    private func archive(_ conv: ChatConversation) {
        withAnimation(.easeInOut(duration: 0.2)) {
            conversations.removeAll { $0.id == conv.id }
        }
        Task { try? await db.archiveConversation(id: conv.id) }
    }

    private func loadConversations() async {
        isLoading = true
        defer { isLoading = false }
        let all = (try? await db.getConversations()) ?? []
        conversations = all.filter { $0.lastPreview != nil || ($0.storedMessageCount ?? 0) > 0 }
    }
}

#Preview {
    ConversationHistoryView(
        onSelectConversation: { _ in },
        onNewConversation: { },
        onDismiss: { }
    )
}
