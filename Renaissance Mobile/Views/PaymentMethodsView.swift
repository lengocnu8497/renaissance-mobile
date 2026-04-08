//
//  PaymentMethodsView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI
import StripePaymentSheet

struct PaymentMethodsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var paymentViewModel = PaymentViewModel()

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
                        if paymentViewModel.isLoadingPaymentMethods {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primaryProfile))
                                .padding(.top, Theme.Spacing.lg)
                        } else if let error = paymentViewModel.paymentMethodsError {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, Theme.Spacing.lg)
                        } else if paymentViewModel.savedCards.isEmpty {
                            VStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "creditcard")
                                    .font(.system(size: 32))
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                                Text("No saved cards yet")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text("Tap \"Add New Card\" to save a payment method.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, Theme.Spacing.xl)
                        } else {
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
            .onAppear {
                Task { await paymentViewModel.fetchPaymentMethods() }
            }
        }
    }

    // MARK: - Add New Card Button
    private var addNewCardButton: some View {
        Button(action: {
            Task {
                let ready = await paymentViewModel.prepareSetupSheet()
                guard ready else { return }
                let result = await paymentViewModel.presentSetupSheet()
                if case PaymentSheetResult.completed = result {
                    await paymentViewModel.fetchPaymentMethods()
                }
            }
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
                ForEach(paymentViewModel.savedCards) { card in
                    PaymentCardView(
                        cardType: card.brand,
                        lastFourDigits: card.last4,
                        expiryDate: card.expiryDate,
                        isDefault: card.isDefault,
                        onMenuTap: {}
                    )
                }
            }
        }
    }
}


#Preview {
    PaymentMethodsView()
}
