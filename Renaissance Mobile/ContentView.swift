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
                onNavigateToProcedures: {
                    // Disabled - do nothing
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

            ProceduresTabView(selectedTab: $selectedTab)
                .tabItem {
                    Label {
                        Text("Procedures")
                    } icon: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "magnifyingglass")

                            Text("Soon")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.primaryProcedures)
                                .cornerRadius(6)
                                .offset(x: 12, y: -8)
                        }
                    }
                }
                .tag(2)
                .disabled(true)

            ProfileTabView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(3)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Prevent switching to Procedures tab
            if newValue == 2 {
                selectedTab = oldValue
            }
        }
    }

    // MARK: - Tab Bar Configuration
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(Theme.Colors.cardBackground.opacity(0.95))

        // Unselected item color
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Theme.Colors.textHomeMuted)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Theme.Colors.textHomeMuted)
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

// MARK: - Procedures Tab View
struct ProceduresTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        ProceduresListView(onBackButtonTapped: {
            selectedTab = 0 // Switch to Home tab
        })
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

// MARK: - Placeholder Views
struct ProceduresView: View {
    var body: some View {
        ProceduresListView()
    }
}

#Preview {
    ContentView()
}
