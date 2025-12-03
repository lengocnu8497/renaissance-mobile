//
//  PaymentCardView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI

struct PaymentCardView: View {
    let cardType: String
    let lastFourDigits: String
    let expiryDate: String
    let isDefault: Bool
    let onMenuTap: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // Card Icon
            cardIcon

            // Card Info
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(cardType)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.textProfilePrimary)

                    Text("••••")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.textProfilePrimary)

                    Text(lastFourDigits)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.textProfilePrimary)
                }

                Text("Exp. \(expiryDate)")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            // Default Badge or Menu
            if isDefault {
                Text("Default")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.small)
            }

            // Menu Button
            Button(action: onMenuTap) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .rotationEffect(.degrees(90))
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.lg)
        .background(Color.white)
        .cornerRadius(Theme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .stroke(Theme.Colors.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Card Icon
    private var cardIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 48, height: 36)

            cardLogoImage
                .font(.system(size: 20))
        }
    }

    private var cardLogoImage: some View {
        Group {
            switch cardType.lowercased() {
            case "visa":
                Image(systemName: "creditcard.fill")
                    .foregroundColor(Color(hex: "#1A1F71"))
            case "mastercard":
                Image(systemName: "creditcard.fill")
                    .foregroundColor(Color(hex: "#EB001B"))
            case "amex":
                Image(systemName: "creditcard.fill")
                    .foregroundColor(Color(hex: "#006FCF"))
            default:
                Image(systemName: "creditcard.fill")
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PaymentCardView(
            cardType: "Visa",
            lastFourDigits: "4242",
            expiryDate: "08/25",
            isDefault: true,
            onMenuTap: {}
        )

        PaymentCardView(
            cardType: "Mastercard",
            lastFourDigits: "5592",
            expiryDate: "11/26",
            isDefault: false,
            onMenuTap: {}
        )
    }
    .padding()
    .background(Theme.Colors.backgroundProfile)
}
