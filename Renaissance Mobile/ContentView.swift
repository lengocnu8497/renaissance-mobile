//
//  ContentView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var searchQuery: String = ""
    @State private var journalAddTrigger = false

    init() {
        configureTabBarAppearance()
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
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)

            ChatTabView(selectedTab: $selectedTab, searchQuery: $searchQuery)
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Chats")
                }
                .tag(1)

            // Center "+" tab — covered by overlay button, intercepted by onChange
            Color.clear
                .tabItem {
                    Image(systemName: "plus")
                    Text("")
                }
                .tag(2)

            PhotoJournalView(addEntryTrigger: $journalAddTrigger)
                .tabItem {
                    Image(systemName: "book.closed.fill")
                    Text("Journal")
                }
                .tag(3)

            ProfileTabView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(4)
        }
        .buttonStyle(TickButtonStyle())
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 2 {
                selectedTab = 3
                journalAddTrigger = true
            }
        }
        .overlay {
            VStack {
                Spacer()
                Button {
                    selectedTab = 3
                    journalAddTrigger = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.Brand.charcoalRose)
                            .frame(width: 62, height: 62)
                            .shadow(
                                color: Theme.Brand.charcoalRose.opacity(0.4),
                                radius: 10, x: 0, y: 4
                            )
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 28)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Tab Bar Configuration
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(Theme.Colors.cardBackground.opacity(0.95))

        // Unselected item color — solid grey fill
        let unselectedGrey = UIColor.systemGray3
        appearance.stackedLayoutAppearance.normal.iconColor = unselectedGrey
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: unselectedGrey
        ]

        // Selected item color
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Theme.Colors.primaryHome)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Theme.Colors.primaryHome)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Chat Tab View
struct ChatTabView: View {
    @Binding var selectedTab: Int
    @Binding var searchQuery: String

    var body: some View {
        ChatView(initialMessage: searchQuery.isEmpty ? nil : searchQuery, onBackButtonTapped: {
            selectedTab = 0 // Switch to Home tab
        })
        .onChange(of: selectedTab) { oldValue, newValue in
            // Clear search query when switching away from chat
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
            selectedTab = 0 // Switch to Home tab
        })
    }
}

#Preview {
    ContentView()
}
