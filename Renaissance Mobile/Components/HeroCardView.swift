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
    var showLaunchingBadge: Bool = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image or fallback gradient
            if let imageName = imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 220)
                    .clipped()
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.pink.opacity(0.3),
                        Color.orange.opacity(0.2),
                        Theme.Colors.primaryHome.opacity(0.4)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 220)
            }

            // Dark gradient overlay for text legibility
            LinearGradient(
                gradient: Gradient(colors: [
                    .clear,
                    .black.opacity(0.6)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)

            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Launching Soon Badge
                if showLaunchingBadge {
                    Text("Launching Soon")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                        .padding(.bottom, Theme.Spacing.md)
                }

                Spacer()

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(Theme.Typography.heroTitle)
                            .foregroundColor(.white)
                            .lineLimit(2)

                        Text(subtitle)
                            .font(Theme.Typography.heroSubtitle)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "arrow.forward")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .frame(height: 220)
        .cornerRadius(Theme.CornerRadius.medium)
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
        imageName: "HeroImage",
        showLaunchingBadge: true
    )
    .padding()
    .background(Theme.Colors.backgroundHome)
}
