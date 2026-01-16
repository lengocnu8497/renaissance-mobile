//
//  QuotaExceededView.swift
//  Renaissance Mobile
//
//  Modal shown when user exceeds quota
//

import SwiftUI

struct QuotaExceededView: View {
    let reason: String
    let onUpgrade: (SubscriptionTier) async -> Void
    let onDismiss: () -> Void

    @State private var selectedTier: SubscriptionTier = .gold
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Title (no icon)
            Text("Ready to unlock your beauty?")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // Message
            Text(reason)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            // Upgrade options
            VStack(spacing: Theme.Spacing.md) {
                Text("Upgrade your plan to continue")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)

                // Silver Tier
                Button(action: {
                    selectedTier = .silver
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Silver Plan")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("30 messages • 5 images • 80 credits")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()

                        // Selection indicator
                        if selectedTier == .silver {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.Colors.gold)
                                .font(.system(size: 20))
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.white.opacity(0.3))
                                .font(.system(size: 20))
                        }

                        Text("$14.99/mo")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(Theme.Spacing.md)
                    .background(selectedTier == .silver ? Color.white.opacity(0.15) : Color.white.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .stroke(selectedTier == .silver ? Theme.Colors.gold : Color.clear, lineWidth: 2)
                    )
                }

                // Gold Tier
                Button(action: {
                    selectedTier = .gold
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Gold Plan")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("POPULAR")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.Colors.gold)
                                    .cornerRadius(4)
                            }
                            Text("75 messages • 15 images • 210 credits")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()

                        // Selection indicator
                        if selectedTier == .gold {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.Colors.gold)
                                .font(.system(size: 20))
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.white.opacity(0.3))
                                .font(.system(size: 20))
                        }

                        Text("$29.99/mo")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(Theme.Spacing.md)
                    .background(selectedTier == .gold ? Color.white.opacity(0.15) : Color.white.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .stroke(selectedTier == .gold ? Theme.Colors.gold : Color.clear, lineWidth: 2)
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            // Actions
            VStack(spacing: Theme.Spacing.md) {
                Button(action: {
                    Task {
                        isProcessing = true
                        await onUpgrade(selectedTier)
                        isProcessing = false
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Text("Upgrade Now")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.white)
                    .cornerRadius(Theme.CornerRadius.medium)
                }
                .disabled(isProcessing)

                Button(action: onDismiss) {
                    Text("Maybe Later")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                .disabled(isProcessing)
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(Theme.Spacing.xl)
        .background(
            Color.black.opacity(0.95)
                .ignoresSafeArea()
        )
    }
}

#Preview {
    QuotaExceededView(
        reason: "You've reached your monthly AI credit limit (80 credits)",
        onUpgrade: { _ in },
        onDismiss: {}
    )
}
