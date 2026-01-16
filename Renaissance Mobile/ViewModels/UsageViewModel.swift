//
//  UsageViewModel.swift
//  Renaissance Mobile
//
//  ViewModel for usage tracking UI
//

import Foundation
import Supabase

@MainActor
@Observable
class UsageViewModel {
    var currentUsage: UsageQuota?
    var isLoading = false
    var errorMessage: String?

    private let usageService: UsageTrackingService

    init(usageService: UsageTrackingService = UsageTrackingService(supabase: supabase)) {
        self.usageService = usageService
    }

    // MARK: - Fetch Usage

    func fetchUsage() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            currentUsage = try await usageService.getCurrentUsage()
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to fetch usage: \(error)")
        }
    }

    // MARK: - Check if Can Send

    func canSendMessage(hasImage: Bool) async -> (canSend: Bool, reason: String?) {
        do {
            return try await usageService.canSendMessage(hasImage: hasImage)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - Computed Properties for UI

    var creditsRemaining: Int {
        currentUsage?.creditsRemaining ?? 0
    }

    var daysUntilReset: Int {
        guard let usage = currentUsage else { return 0 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: usage.periodEnd).day ?? 0
        return max(0, days)
    }

    var formattedResetDate: String {
        guard let usage = currentUsage else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: usage.periodEnd)
    }
}
