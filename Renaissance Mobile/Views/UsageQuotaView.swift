//
//  UsageQuotaView.swift
//  Renaissance Mobile
//
//  Simplified usage quota display - credits only
//

import SwiftUI

struct UsageQuotaView: View {
    @State private var viewModel = UsageViewModel()

    var body: some View {
        // Only show if user has a subscription (not loading and has usage data)
        if !viewModel.isLoading, viewModel.currentUsage != nil, viewModel.errorMessage == nil {
            HStack(spacing: Theme.Spacing.md) {
                // Token/Credit icon
                Image(systemName: "star.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.Colors.gold)

                // Credits remaining text
                Text("\(viewModel.creditsRemaining) credits remaining")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.Colors.textProfilePrimary)

                Spacer()

                // Optional: Reset info
                if viewModel.daysUntilReset > 0 {
                    Text("Resets in \(viewModel.daysUntilReset)d")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.borderLight, lineWidth: 1)
            )
            .task {
                await viewModel.fetchUsage()
            }
        }
    }
}

#Preview {
    UsageQuotaView()
        .padding()
}
