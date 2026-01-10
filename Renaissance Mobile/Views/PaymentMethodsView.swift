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
    @State private var savedCards: [PaymentCard] = PaymentMethodsView.sampleCards
    @State private var showAddNewCard = false
    @State private var paymentViewModel = PaymentViewModel()
    @State private var showingPaymentSheet = false
    @State private var paymentMessage: String?
    @State private var isPaymentSuccess = false

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

                        // Test Payment Button (Stripe PaymentSheet)
                        testPaymentButton

                        // Payment status message
                        if let message = paymentMessage {
                            Text(message)
                                .font(.system(size: 14))
                                .foregroundColor(isPaymentSuccess ? .green : .red)
                                .multilineTextAlignment(.center)
                                .padding()
                        }

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
            .sheet(isPresented: $showAddNewCard) {
                AddNewCardView()
            }
            .onChange(of: showingPaymentSheet) { _, isPresented in
                if isPresented {
                    Task {
                        let result = await paymentViewModel.presentPaymentSheet()
                        showingPaymentSheet = false
                        handlePaymentResult(result)
                    }
                }
            }
        }
    }

    // MARK: - Add New Card Button
    private var addNewCardButton: some View {
        Button(action: {
            showAddNewCard = true
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

    // MARK: - Test Payment Button
    private var testPaymentButton: some View {
        Button(action: {
            didTapCheckoutButton()
        }) {
            HStack(spacing: Theme.Spacing.md) {
                if paymentViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)

                    Text("Test Stripe Payment ($50)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(red: 208/255, green: 187/255, blue: 149/255))
            .cornerRadius(Theme.CornerRadius.large)
        }
        .disabled(paymentViewModel.isLoading)
    }

    // MARK: - Payment Flow

    private func didTapCheckoutButton() {
        // Prepare Payment Sheet with IntentConfiguration
        let success = paymentViewModel.preparePaymentSheet(
            amountCents: 5000, // $50.00
            currency: "USD",
            metadata: [
                "transaction_type": "booking",
                "description": "Test payment from Payment Methods screen"
            ]
        )

        if success {
            showingPaymentSheet = true
        } else {
            paymentMessage = "Failed to initialize payment"
            isPaymentSuccess = false
        }
    }

    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            // Payment completed - show a confirmation screen
            paymentMessage = "✅ Payment completed successfully!"
            isPaymentSuccess = true
            print("✅ Payment completed successfully")

        case .failed(let error):
            // PaymentSheet encountered an unrecoverable error
            paymentMessage = "❌ Payment failed: \(error.localizedDescription)"
            isPaymentSuccess = false
            print("❌ Payment failed:", error)

        case .canceled:
            // Customer canceled - do nothing
            paymentMessage = nil
            print("Payment canceled by user")
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
