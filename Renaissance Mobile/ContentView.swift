//
//  ContentView.swift
//  Renaissance Mobile
//

import SwiftUI

struct ContentView: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @State private var selectedTab = 0
    @State private var searchQuery: String = ""
    @State private var chatProcedureContext: Procedure? = nil
    @State private var chatLinkedSavedProcedureId: UUID? = nil
    @State private var chatConversationIdToLoad: UUID? = nil
    @State private var chatSessionId: UUID = UUID()
    @State private var journalAddTrigger = false
    @State private var isKeyboardVisible = false
    @State private var showOnboarding = false
    @State private var hasResolvedOnboardingState = false
    @State private var isResolvingOnboardingState = false
    @State private var onboardingSessionID = UUID()
    @State private var lastOnboardingDismissedAt: Date?

    private let userProfileService = UserProfileService(supabase: supabase)

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
            if !hasResolvedOnboardingState {
                showOnboarding = false
            }
        }
        .task {
            await resolveOnboardingPresentation(trigger: "initialTask")
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
            Task {
                await resolveOnboardingPresentation(trigger: "subscriptionStatusChanged")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingStateChanged)) { _ in
            Task {
                await resolveOnboardingPresentation(trigger: "onboardingStateChanged")
            }
        }
        .fullScreenCover(isPresented: onboardingPresentationBinding) {
            OnboardingFlowView(onboardingSessionID: onboardingSessionID) {
                Task { @MainActor in
                    await resolveOnboardingPresentation(trigger: "onboardingFlowFinished")
                }
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

private extension ContentView {
    var onboardingPresentationBinding: Binding<Bool> {
        Binding(
            get: { showOnboarding },
            set: { newValue in
                if showOnboarding == newValue { return }

                logOnboardingEvent(
                    "content.onboarding.bindingChanged",
                    details: [
                        "sessionID": onboardingSessionID.uuidString,
                        "oldPresented": String(showOnboarding),
                        "newPresented": String(newValue),
                        "storeShouldPresent": String(OnboardingStore.shouldPresentOnboarding)
                    ]
                )

                if !newValue {
                    lastOnboardingDismissedAt = Date()
                }

                showOnboarding = newValue
            }
        )
    }

    @MainActor
    func resolveOnboardingPresentation(trigger: String) async {
        guard !isResolvingOnboardingState else {
            logOnboardingEvent(
                "content.gate.skippedWhileResolving",
                details: ["trigger": trigger]
            )
            return
        }

        isResolvingOnboardingState = true
        defer { isResolvingOnboardingState = false }

        let decision = await OnboardingStore.resolvePresentationDecision(
            trigger: trigger,
            using: subscriptionStore,
            profileService: userProfileService
        )

        logOnboardingEvent(
            "content.gate.evaluate",
            details: [
                "trigger": trigger,
                "userID": decision.userID,
                "status": decision.status.rawValue,
                "completionReason": decision.completionReason?.rawValue,
                "hasActiveSubscription": String(decision.hasActiveSubscription),
                "hasBackendPremiumAccess": decision.hasBackendPremiumAccess.map { String(describing: $0) },
                "shouldPresent": String(decision.shouldPresent)
            ]
        )

        applyOnboardingDecision(decision, trigger: trigger)
        hasResolvedOnboardingState = true
    }

    @MainActor
    func applyOnboardingDecision(_ decision: OnboardingPresentationDecision, trigger: String) {
        if decision.shouldPresent {
            if !showOnboarding {
                if let lastOnboardingDismissedAt,
                   Date().timeIntervalSince(lastOnboardingDismissedAt) < 2 {
                    logOnboardingEvent(
                        "content.onboarding.representedAfterDismiss",
                        details: [
                            "trigger": trigger,
                            "userID": decision.userID,
                            "status": decision.status.rawValue,
                            "completionReason": decision.completionReason?.rawValue
                        ]
                    )
                }

                onboardingSessionID = UUID()
                logOnboardingEvent(
                    "content.onboarding.present",
                    details: [
                        "trigger": trigger,
                        "sessionID": onboardingSessionID.uuidString,
                        "userID": decision.userID
                    ]
                )
            }
        } else if showOnboarding {
            lastOnboardingDismissedAt = Date()
            logOnboardingEvent(
                "content.onboarding.dismissRequested",
                details: [
                    "trigger": trigger,
                    "sessionID": onboardingSessionID.uuidString,
                    "userID": decision.userID,
                    "status": decision.status.rawValue,
                    "completionReason": decision.completionReason?.rawValue
                ]
            )
        }

        showOnboarding = decision.shouldPresent
    }

    func logOnboardingEvent(_ event: String, details: [String: String?] = [:]) {
        let payload = details
            .compactMap { key, value -> String? in
                guard let value else { return nil }
                return "\(key)=\(value)"
            }
            .sorted()
            .joined(separator: " ")

        if payload.isEmpty {
            print("[OnboardingContent] \(event)")
        } else {
            print("[OnboardingContent] \(event) \(payload)")
        }
    }
}

#Preview {
    ContentView()
}
