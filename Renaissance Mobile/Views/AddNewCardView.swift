//
//  AddNewCardView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/20/25.
//

import SwiftUI

struct AddNewCardView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var cardholderName = ""
    @State private var cardNumber = ""
    @State private var expiryDate = ""
    @State private var cvv = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundProfile
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        // Cardholder Name
                        cardholderNameField
                            .padding(.top, Theme.Spacing.lg)

                        // Card Number
                        cardNumberField

                        // Expiry Date and CVV
                        HStack(spacing: Theme.Spacing.lg) {
                            expiryDateField
                            cvvField
                        }

                        // Error/Success Messages
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal, Theme.Spacing.lg)
                        }

                        if let successMessage {
                            Text(successMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                                .padding(.horizontal, Theme.Spacing.lg)
                        }

                        // Save Card Button
                        saveCardButton
                            .padding(.top, Theme.Spacing.md)

                        // Security Message
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textSecondary)

                            Text("Your payment info is stored securely")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding(.top, Theme.Spacing.md)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
            }
            .navigationTitle("Add New Card")
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

    // MARK: - Cardholder Name Field
    private var cardholderNameField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Cardholder Name")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textProfilePrimary)

            TextField("Enter name on card", text: $cardholderName)
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.textProfilePrimary)
                .textContentType(.name)
                .autocapitalization(.words)
                .padding(Theme.Spacing.lg)
                .background(Color.white)
                .cornerRadius(Theme.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(Theme.Colors.borderLight, lineWidth: 1)
                )
        }
    }

    // MARK: - Card Number Field
    private var cardNumberField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Card Number")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textProfilePrimary)

            HStack {
                TextField("0000 0000 0000 0000", text: $cardNumber)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textProfilePrimary)
                    .keyboardType(.numberPad)
                    .onChange(of: cardNumber) { _, newValue in
                        cardNumber = formatCardNumber(newValue)
                    }

                Image(systemName: "creditcard.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.lg)
            .background(Color.white)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.borderLight, lineWidth: 1)
            )
        }
    }

    // MARK: - Expiry Date Field
    private var expiryDateField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Expiry Date")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textProfilePrimary)

            TextField("MM/YY", text: $expiryDate)
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.textProfilePrimary)
                .keyboardType(.numberPad)
                .onChange(of: expiryDate) { _, newValue in
                    expiryDate = formatExpiryDate(newValue)
                }
                .padding(Theme.Spacing.lg)
                .background(Color.white)
                .cornerRadius(Theme.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(Theme.Colors.borderLight, lineWidth: 1)
                )
        }
    }

    // MARK: - CVV Field
    private var cvvField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("CVV")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textProfilePrimary)

            HStack {
                SecureField("123", text: $cvv)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textProfilePrimary)
                    .keyboardType(.numberPad)
                    .onChange(of: cvv) { _, newValue in
                        cvv = String(newValue.prefix(4))
                    }

                Button(action: {
                    // Show CVV help
                }) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(Color.white)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.borderLight, lineWidth: 1)
            )
        }
    }

    // MARK: - Save Card Button
    private var saveCardButton: some View {
        Button(action: {
            Task {
                await handleSaveCard()
            }
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.textProfilePrimary))
                } else {
                    Text("Save Card")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundColor(Theme.Colors.textProfilePrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                isFormValid ? Theme.Colors.primaryProfile.opacity(0.3) : Color.gray.opacity(0.2)
            )
            .cornerRadius(Theme.CornerRadius.large)
        }
        .disabled(!isFormValid || isProcessing)
    }

    // MARK: - Validation
    private var isFormValid: Bool {
        !cardholderName.isEmpty &&
        isValidCardNumber(cardNumber) &&
        isValidExpiryDate(expiryDate) &&
        isValidCVV(cvv)
    }

    private func isValidCardNumber(_ number: String) -> Bool {
        let digits = number.replacingOccurrences(of: " ", with: "")
        return digits.count >= 13 && digits.count <= 19
    }

    private func isValidExpiryDate(_ date: String) -> Bool {
        let components = date.split(separator: "/")
        guard components.count == 2,
              let month = Int(components[0]),
              let year = Int(components[1]) else {
            return false
        }

        // Validate month
        guard month >= 1 && month <= 12 else {
            return false
        }

        // Validate year (not expired)
        let currentYear = Calendar.current.component(.year, from: Date()) % 100
        let currentMonth = Calendar.current.component(.month, from: Date())

        if year < currentYear {
            return false
        } else if year == currentYear && month < currentMonth {
            return false
        }

        return true
    }

    private func isValidCVV(_ cvv: String) -> Bool {
        return cvv.count >= 3 && cvv.count <= 4
    }

    // MARK: - Formatting Helpers
    private func formatCardNumber(_ value: String) -> String {
        let digits = value.replacingOccurrences(of: " ", with: "")
        let limitedDigits = String(digits.prefix(19))

        var formatted = ""
        for (index, character) in limitedDigits.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted.append(character)
        }

        return formatted
    }

    private func formatExpiryDate(_ value: String) -> String {
        let digits = value.replacingOccurrences(of: "/", with: "")
        let limitedDigits = String(digits.prefix(4))

        if limitedDigits.count <= 2 {
            return limitedDigits
        } else {
            let month = String(limitedDigits.prefix(2))
            let year = String(limitedDigits.dropFirst(2))
            return "\(month)/\(year)"
        }
    }

    // MARK: - Handle Save Card
    private func handleSaveCard() async {
        errorMessage = nil
        successMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        // Validate all fields
        guard isFormValid else {
            errorMessage = "Please fill in all fields correctly"
            return
        }

        // TODO: Integrate with payment processor (Stripe, etc.)
        // For now, simulate a successful save
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

        successMessage = "Card saved successfully"

        // Clear fields
        cardholderName = ""
        cardNumber = ""
        expiryDate = ""
        cvv = ""

        // Dismiss after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}

#Preview {
    AddNewCardView()
}
