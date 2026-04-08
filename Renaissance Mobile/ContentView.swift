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
    @State private var showOnboarding = !OnboardingStore.hasCompleted

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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .buttonStyle(TickButtonStyle())
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
        .onAppear {
            if !OnboardingStore.hasCompleted {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView {
                showOnboarding = false
            }
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            navItem(icon: "house", label: "Home", tag: 0)
            navItem(icon: "bubble.left", label: "Chats", tag: 1)
            navItem(icon: "doc.text", label: "Journal", tag: 3)
            navItem(icon: "person", label: "Profile", tag: 5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.95), Color(hex: "#F8F9F4").opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: Color(hex: "#3D2B2E").opacity(0.12), radius: 18, x: 0, y: 4)
    }

    private func navItem(icon: String, label: String, tag: Int) -> some View {
        let isActive = selectedTab == tag
        return Button {
            selectedTab = tag
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? Color(hex: "#976769") : Color(hex: "#8D9288"))
                Text(label)
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                    .foregroundColor(isActive ? Color(hex: "#976769") : Color(hex: "#8D9288"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                isActive
                    ? LinearGradient(
                        colors: [Color(hex: "#F4E2DF"), Color(hex: "#F8EFED")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
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
        NavigationStack {
            ProfileView(onBackButtonTapped: {
                selectedTab = 0
            })
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    ContentView()
}
