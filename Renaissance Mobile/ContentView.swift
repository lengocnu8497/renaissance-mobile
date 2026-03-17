//
//  ContentView.swift
//  Renaissance Mobile
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var searchQuery: String = ""
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
                    selectedTab = 1
                },
                onNavigateToJournal: {
                    selectedTab = 3
                }
            )
            .tag(0)

            ChatTabView(selectedTab: $selectedTab, searchQuery: $searchQuery)
                .tag(1)

            Color.clear
                .tag(2)

            PhotoJournalView(addEntryTrigger: $journalAddTrigger, onBackButtonTapped: {
                selectedTab = 0
            })
            .tag(3)

            ProfileTabView(selectedTab: $selectedTab)
                .tag(4)
        }
        .buttonStyle(TickButtonStyle())
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 2 {
                selectedTab = 3
                journalAddTrigger = true
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectedTab != 1 {
                customTabBar
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
                    .padding(.top, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: isKeyboardVisible)
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

            // Center plus button
            Button {
                selectedTab = 3
                journalAddTrigger = true
            } label: {
                Circle()
                    .fill(Color(hex: "#3D2B2E"))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color(hex: "#3D2B2E").opacity(0.22), radius: 8, x: 0, y: 4)
            }
            .frame(maxWidth: .infinity)

            navItem(icon: "doc.text", label: "Journal", tag: 3)
            navItem(icon: "person", label: "Profile", tag: 4)
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

    var body: some View {
        ChatView(initialMessage: searchQuery.isEmpty ? nil : searchQuery, onBackButtonTapped: {
            selectedTab = 0
        })
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue == 1 && newValue != 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    searchQuery = ""
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
