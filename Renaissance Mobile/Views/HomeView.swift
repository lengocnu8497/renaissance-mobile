//
//  HomeView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundLight
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Welcome header
                    welcomeHeader

                    // Navigation cards
                    navigationCards

                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Subviews
    private var welcomeHeader: some View {
        HStack {
            Text("Welcome, Nu")
                .font(Theme.Typography.welcomeHeader)
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.xxxl)
        .padding(.bottom, Theme.Spacing.xxl)
    }

    private var navigationCards: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Concierge Chat Card
            NavigationLink(destination: ChatView()) {
                NavigationCardView(
                    icon: "text.bubble.fill",
                    title: "Concierge Chat",
                    subtitle: "Get expert advice",
                    iconBackgroundColor: Theme.Colors.iconCircleBackground,
                    iconColor: Theme.Colors.primary
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Explore Procedures Card
            NavigationCardView(
                icon: "storefront.fill",
                title: "Explore Procedures",
                subtitle: "Browse treatments",
                iconBackgroundColor: Theme.Colors.iconCircleBackground,
                iconColor: Theme.Colors.primary
            )
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

#Preview {
    HomeView()
}
