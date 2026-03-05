//
//  CategoryCardView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct CategoryCardView: View {
    let stickerName: String
    let title: String
    var stickerSize: CGFloat = 100

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            stickerImage
            titleText
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
        .background(Color(hex: "#C4929A"))
        .cornerRadius(Theme.CornerRadius.medium)
        .shadow(
            color: Theme.Shadow.card.color,
            radius: Theme.Shadow.card.radius,
            x: Theme.Shadow.card.x,
            y: Theme.Shadow.card.y
        )
    }

    // MARK: - Subviews
    private var stickerImage: some View {
        ZStack {
            // White silhouette slightly larger — forms the solid outline
            Image(stickerName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 106, height: 106)
                .overlay(Color.white)
                .mask {
                    Image(stickerName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 106, height: 106)
                }
            // Actual sticker on top
            Image(stickerName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
        }
        .scaleEffect(stickerSize / 100)
    }

    private var titleText: some View {
        Text(title)
            .font(Theme.Typography.categoryLabel)
            .foregroundColor(.white)
    }
}

#Preview {
    HStack(spacing: 16) {
        CategoryCardView(stickerName: "sticker_facial", title: "Facials")
        CategoryCardView(stickerName: "sticker_body", title: "Body")
    }
    .padding()
    .background(Theme.Colors.backgroundHome)
}
