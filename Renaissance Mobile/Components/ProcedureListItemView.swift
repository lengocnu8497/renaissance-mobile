//
//  ProcedureListItemView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct ProcedureListItemView: View {
    let procedure: Procedure

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // Placeholder image
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 96, height: 96)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.5))
                )

            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(procedure.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.Colors.textProceduresPrimary)
                    .lineLimit(1)

                Text(procedure.description)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textProceduresSubtle)
                    .lineLimit(2)

                // Category tag
                HStack {
                    Text(procedure.category)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.textProceduresPrimary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.accentProcedures.opacity(0.3))
                        .cornerRadius(6)

                    Spacer()
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.textProceduresPrimary)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
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
    ProcedureListItemView(
        procedure: Procedure(
            name: "Microneedling",
            description: "For skin rejuvenation and texture improvement",
            category: "Non-Surgical",
            imageName: nil
        )
    )
    .padding()
}
