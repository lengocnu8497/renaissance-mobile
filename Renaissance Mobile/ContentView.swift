//
//  ContentView.swift
//  Renaissance Mobile
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var searchQuery: String = ""
    @State private var chatProcedureContext: Procedure? = nil
    @State private var chatLinkedSavedProcedureId: UUID? = nil
    @State private var chatConversationIdToLoad: UUID? = nil
    @State private var chatSessionId: UUID = UUID()
    @State private var journalAddTrigger = false
    @State private var isKeyboardVisible = false

    init() {
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            PostLoginHomeView(
                onNavigateToChat: { query in
                    searchQuery = query
                    chatProcedureContext = nil
                    chatSessionId = UUID()
                    selectedTab = 1
                },
                onNavigateToJournal: {
                    selectedTab = 3
                }
            )
            .tag(0)

            ChatTabView(
                selectedTab: $selectedTab,
                searchQuery: $searchQuery,
                procedureContext: $chatProcedureContext,
                sessionId: chatSessionId,
                linkedSavedProcedureId: chatLinkedSavedProcedureId,
                conversationIdToLoad: chatConversationIdToLoad
            )
            .tag(1)

            Color.clear
                .tag(2)

            PhotoJournalView(addEntryTrigger: $journalAddTrigger, onBackButtonTapped: {
                selectedTab = 0
            })
            .tag(3)

            ResearchTabView(
                onNavigateToChat: { query, procedure, savedProcedureId in
                    searchQuery = query
                    chatProcedureContext = procedure
                    chatLinkedSavedProcedureId = savedProcedureId
                    chatConversationIdToLoad = nil
                    chatSessionId = UUID()
                    selectedTab = 1
                },
                onReopenConversation: { conversationId in
                    chatConversationIdToLoad = conversationId
                    chatLinkedSavedProcedureId = nil
                    chatProcedureContext = nil
                    searchQuery = ""
                    chatSessionId = UUID()
                    selectedTab = 1
                }
            )
            .tag(4)

            ProfileTabView(selectedTab: $selectedTab)
                .tag(5)
        }
        .buttonStyle(TickButtonStyle())
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 2 {
                selectedTab = 3
                journalAddTrigger = true
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectedTab != 1 && selectedTab != 5 {
                customTabBar
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
                    .padding(.top, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: isKeyboardVisible)
        .animation(.easeOut(duration: 0.22), value: selectedTab)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            navItem(icon: selectedTab == 0 ? "house.fill" : "house", label: "Home", tag: 0)
            navItem(icon: "bubble.left", label: "Chats", tag: 1)
            navItem(icon: selectedTab == 3 ? "doc.text.fill" : "doc.text", label: "Journal", tag: 3)
            navItem(icon: selectedTab == 4 ? "bookmark.fill" : "bookmark", label: "Research", tag: 4)
            navItem(icon: "person", label: "Profile", tag: 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color(hex: "#C4929A").opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color(hex: "#3D2B2E").opacity(0.13), radius: 16, x: 0, y: 4)
    }

    private func navItem(icon: String, label: String, tag: Int) -> some View {
        let isActive = selectedTab == tag
        return Button {
            selectedTab = tag
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? Color(hex: "#8E4C5C") : Color(hex: "#B8A9AB"))
                Text(label)
                    .font(.system(size: 9, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? Color(hex: "#8E4C5C") : Color(hex: "#B8A9AB"))
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }
}

// MARK: - Chat Tab View

struct ChatTabView: View {
    @Binding var selectedTab: Int
    @Binding var searchQuery: String
    @Binding var procedureContext: Procedure?
    var sessionId: UUID
    var linkedSavedProcedureId: UUID? = nil
    var conversationIdToLoad: UUID? = nil

    var body: some View {
        ChatView(
            initialMessage: searchQuery.isEmpty ? nil : searchQuery,
            procedureContext: procedureContext,
            savedProcedureId: linkedSavedProcedureId,
            conversationIdToLoad: conversationIdToLoad,
            onBackButtonTapped: {
                selectedTab = 0
            }
        )
        .id(sessionId)
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue == 1 && newValue != 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    searchQuery = ""
                    procedureContext = nil
                }
            }
        }
    }
}

// MARK: - Profile Tab View

struct ProfileTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        ProfileView(onBackButtonTapped: {
            selectedTab = 0
        })
    }
}

#Preview {
    ContentView()
}
