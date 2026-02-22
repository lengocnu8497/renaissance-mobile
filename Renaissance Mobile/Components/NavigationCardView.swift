//
//  NavigationCardView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct NavigationCardView: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconBackgroundColor: Color
    let iconColor: Color
    var backgroundColor: Color = Theme.Colors.cardBackground
    var titleColor: Color = Color(red: 61/255, green: 43/255, blue: 46/255)
    var subtitleColor: Color = Color(red: 184/255, green: 169/255, blue: 171/255)

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            iconCircle
            textContent
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
        .padding(.horizontal, Theme.Spacing.xl)
        .background(backgroundColor)
        .cornerRadius(Theme.CornerRadius.large)
        .shadow(
            color: Theme.Shadow.card.color,
            radius: Theme.Shadow.card.radius,
            x: Theme.Shadow.card.x,
            y: Theme.Shadow.card.y
        )
    }

    // MARK: - Subviews
    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: Theme.IconSize.iconCircle, height: Theme.IconSize.iconCircle)

            Image(systemName: icon)
                .font(.system(size: Theme.IconSize.large, weight: .light))
                .foregroundColor(iconColor)
        }
    }

    private var textContent: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typography.cardTitle)
                .foregroundColor(titleColor)

            Text(subtitle)
                .font(Theme.Typography.cardSubtitle)
                .foregroundColor(subtitleColor)
        }
    }
}

#Preview {
    NavigationCardView(
        icon: "text.bubble.fill",
        title: "Concierge Chat",
        subtitle: "Get expert advice",
        iconBackgroundColor: Theme.Colors.iconCircleBackground,
        iconColor: Theme.Colors.primary
    )
    .padding()
}
