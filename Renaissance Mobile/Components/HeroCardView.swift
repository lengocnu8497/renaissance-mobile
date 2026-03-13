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
        HStack(alignment: .center, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {

                // Category label row
                HStack(spacing: Theme.Spacing.sm) {

                    if showLaunchingBadge {
                        Text("Launching Soon")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.Colors.primaryHome)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.Colors.iconCircleBackground)
                            .cornerRadius(Theme.CornerRadius.pill)
                    }
                }

                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Theme.Colors.textHomePrimary)
                    .lineLimit(2)

                Text(subtitle)
                    .font(Theme.Typography.heroSubtitle)
                    .foregroundColor(Theme.Colors.textHomeMuted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Arrow button
            Circle()
                .fill(Theme.Colors.textHomePrimary)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )
        }
        .padding(Theme.Spacing.lg)
        .background(Color.white)
        .cornerRadius(Theme.CornerRadius.medium)
        .shadow(
            color: Theme.Shadow.elevated.color,
            radius: Theme.Shadow.elevated.radius,
            x: Theme.Shadow.elevated.x,
            y: Theme.Shadow.elevated.y
        )
    }
}

#Preview {
    HeroCardView(
        title: "Explore Procedures",
        subtitle: "Find the perfect treatment for you.",
        imageName: nil,
        showLaunchingBadge: true
    )
    .padding()
    .background(Color(hex: "#FFF8F6"))
}