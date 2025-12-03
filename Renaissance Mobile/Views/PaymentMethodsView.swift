//
//  PaymentMethodsView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI

struct PaymentMethodsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var savedCards: [PaymentCard] = PaymentMethodsView.sampleCards

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundProfile
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        // Add New Card Button
                        addNewCardButton
                            .padding(.top, Theme.Spacing.lg)

                        // Saved Cards Section
                        if !savedCards.isEmpty {
                            savedCardsSection
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
            }
            .navigationTitle("Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.Colors.textProfilePrimary)
                    }
                }
            }
        }
    }

    // MARK: - Add New Card Button
    private var addNewCardButton: some View {
        Button(action: {
            // Handle add new card
        }) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Theme.Colors.textProfilePrimary)

                Text("Add New Card")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.Colors.textProfilePrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Theme.Colors.primaryProfile.opacity(0.3))
            .cornerRadius(Theme.CornerRadius.large)
        }
    }

    // MARK: - Saved Cards Section
    private var savedCardsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("SAVED CARDS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.sm)

            VStack(spacing: Theme.Spacing.lg) {
                ForEach(savedCards) { card in
                    PaymentCardView(
                        cardType: card.cardType,
                        lastFourDigits: card.lastFourDigits,
                        expiryDate: card.expiryDate,
                        isDefault: card.isDefault,
                        onMenuTap: {
                            // Handle menu tap for this card
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Payment Card Model
struct PaymentCard: Identifiable {
    let id = UUID()
    let cardType: String
    let lastFourDigits: String
    let expiryDate: String
    var isDefault: Bool
}

// MARK: - Sample Data
extension PaymentMethodsView {
    static let sampleCards: [PaymentCard] = [
        PaymentCard(
            cardType: "Visa",
            lastFourDigits: "4242",
            expiryDate: "08/25",
            isDefault: true
        ),
        PaymentCard(
            cardType: "Mastercard",
            lastFourDigits: "5592",
            expiryDate: "11/26",
            isDefault: false
        ),
        PaymentCard(
            cardType: "Amex",
            lastFourDigits: "1002",
            expiryDate: "03/27",
            isDefault: false
        )
    ]
}

#Preview {
    PaymentMethodsView()
}
