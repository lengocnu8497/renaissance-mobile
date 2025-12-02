//
//  HeroCardView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct HeroCardView: View {
    let title: String
    let subtitle: String
    let imageName: String?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.pink.opacity(0.3),
                    Color.orange.opacity(0.2),
                    Theme.Colors.primaryHome.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)
            .cornerRadius(Theme.CornerRadius.medium)

            // Content overlay
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Typography.heroTitle)
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(Theme.Typography.heroSubtitle)
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Arrow button
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "arrow.forward")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            .padding(Theme.Spacing.lg)
        }
        .frame(height: 200)
        .shadow(
            color: Theme.Shadow.card.color,
            radius: Theme.Shadow.card.radius,
            x: Theme.Shadow.card.x,
            y: Theme.Shadow.card.y
        )
    }
}

#Preview {
    HeroCardView(
        title: "Explore Procedures",
        subtitle: "Find the perfect treatment for you.",
        imageName: nil
    )
    .padding()
    .background(Theme.Colors.backgroundHome)
}
