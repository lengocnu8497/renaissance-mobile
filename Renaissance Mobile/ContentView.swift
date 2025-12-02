//
//  ContentView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    init() {
        configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            PostLoginHomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)

            ChatTabView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Chats")
                }
                .tag(1)

            FavoritesView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Favorites")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(3)
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

    var body: some View {
        ChatView(onBackButtonTapped: {
            selectedTab = 0 // Switch to Home tab
        })
    }
}

// MARK: - Placeholder Views
struct FavoritesView: View {
    var body: some View {
        NavigationStack {
            Text("Favorites")
                .navigationTitle("Favorites")
        }
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            Text("Profile")
                .navigationTitle("Profile")
        }
    }
}

#Preview {
    ContentView()
}
