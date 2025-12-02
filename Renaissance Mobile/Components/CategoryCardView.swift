//
//  CategoryCardView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct CategoryCardView: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            iconCircle
            titleText
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .shadow(
            color: Theme.Shadow.card.color,
            radius: Theme.Shadow.card.radius,
            x: Theme.Shadow.card.x,
            y: Theme.Shadow.card.y
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Subviews
    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(Theme.Colors.categoryCircleBackground)
                .frame(width: 48, height: 48)

            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(Theme.Colors.primaryHome)
        }
    }

    private var titleText: some View {
        Text(title)
            .font(Theme.Typography.categoryLabel)
            .foregroundColor(Theme.Colors.textHomePrimary)
    }
}

#Preview {
    HStack(spacing: 16) {
        CategoryCardView(icon: "face.smiling", title: "Facial")
        CategoryCardView(icon: "figure.stand", title: "Body")
    }
    .padding()
    .background(Theme.Colors.backgroundHome)
}
