//
//  PostLoginHomeView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct PostLoginHomeView: View {
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    searchBar
                    spacer(height: Theme.Spacing.sm)
                    heroSection
                    categoriesSection
                }
                .padding(.bottom, 100) // Space for bottom tab bar
            }
            .background(Theme.Colors.backgroundHome)
            .navigationBarHidden(true)
        }
    }

    // MARK: - Subviews
    private var headerSection: some View {
        Text("Hello, Jessica")
            .font(Theme.Typography.homeHeader)
            .foregroundColor(Theme.Colors.textHomePrimary)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.lg)
    }

    private var searchBar: some View {
        HStack(spacing: 0) {
            TextField("Ask about a procedure...", text: $searchText)
                .font(Theme.Typography.inputText)
                .foregroundColor(Theme.Colors.textHomePrimary)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.inputBackground)
                .cornerRadius(Theme.CornerRadius.medium, corners: [.topLeft, .bottomLeft])

            Button(action: {}) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Theme.Colors.primaryHome)
                    .cornerRadius(Theme.CornerRadius.medium, corners: [.topRight, .bottomRight])
            }
        }
        .cornerRadius(Theme.CornerRadius.medium)
        .shadow(
            color: Theme.Shadow.card.color,
            radius: 2,
            x: 0,
            y: 1
        )
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }

    private var heroSection: some View {
        HeroCardView(
            title: "Explore Procedures",
            subtitle: "Find the perfect treatment for you.",
            imageName: nil
        )
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Popular Categories")
                .font(Theme.Typography.sectionTitle)
                .foregroundColor(Theme.Colors.textHomePrimary)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.sm)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Theme.Spacing.lg),
                    GridItem(.flexible(), spacing: Theme.Spacing.lg)
                ],
                spacing: Theme.Spacing.lg
            ) {
                CategoryCardView(icon: "face.smiling", title: "Facial")
                CategoryCardView(icon: "figure.stand", title: "Body")
                CategoryCardView(icon: "cross.vial", title: "Injectables")
                CategoryCardView(icon: "heart.text.square", title: "Wellness")
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    // MARK: - Helper
    private func spacer(height: CGFloat) -> some View {
        Color.clear.frame(height: height)
    }
}

#Preview {
    PostLoginHomeView()
}
