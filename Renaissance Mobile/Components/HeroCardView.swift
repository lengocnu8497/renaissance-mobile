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
        HStack(alignment: .center, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(subtitle)
                    .font(Theme.Typography.heroSubtitle)
                    .foregroundColor(Color.white.opacity(0.6))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Arrow button
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, 28)
        .background(Theme.Brand.charcoalRose)
        .cornerRadius(Theme.CornerRadius.medium)
        .shadow(
            color: Theme.Brand.charcoalRose.opacity(0.3),
            radius: 16,
            x: 0,
            y: 6
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
    .background(Color(hex: "#FFF8F6"))
}