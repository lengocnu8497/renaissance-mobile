//
//  OnboardingStore.swift
//  Renaissance Mobile
//
//  Persists procedure data collected during pre-login onboarding.
//  After the user authenticates, PostLoginHomeView calls applyIfNeeded()
//  to bootstrap weekly check-ins from the stored procedure + date.
//

import Foundation
import Supabase

extension Notification.Name {
    static let subscriptionLinked = Notification.Name("rena_subscription_linked")
}

struct OnboardingStore {

    // MARK: - UserDefaults Keys

    private static let completedKey        = "rena_onboarding_completed"
    private static let procedureNameKey  = "rena_onboarding_procedure_name"
    private static let procedureDateKey  = "rena_onboarding_procedure_date"
    private static let customerIdKey     = "rena_onboarding_stripe_customer_id"
    private static let subscriptionIdKey = "rena_onboarding_stripe_subscription_id"
    private static let emailKey          = "rena_onboarding_email"

    // MARK: - Completion Flag

    static var hasCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: completedKey) }
    }

    // MARK: - Pending Procedure Data

    static var pendingProcedureName: String? {
        UserDefaults.standard.string(forKey: procedureNameKey)
    }

    static var pendingProcedureDate: Date? {
        UserDefaults.standard.object(forKey: procedureDateKey) as? Date
    }

    // MARK: - Pending Stripe Data

    static var pendingStripeCustomerId: String? {
        UserDefaults.standard.string(forKey: customerIdKey)
    }

    static var pendingStripeSubscriptionId: String? {
        UserDefaults.standard.string(forKey: subscriptionIdKey)
    }

    static var pendingEmail: String? {
        UserDefaults.standard.string(forKey: emailKey)
    }

    static func saveStripeData(email: String, customerId: String, subscriptionId: String) {
        UserDefaults.standard.set(email, forKey: emailKey)
        UserDefaults.standard.set(customerId, forKey: customerIdKey)
        UserDefaults.standard.set(subscriptionId, forKey: subscriptionIdKey)
    }

    /// Links the pending Stripe subscription to the now-authenticated Supabase user.
    /// Safe to call on every sign-up — no-ops if no pending Stripe data exists.
    @MainActor
    static func linkSubscriptionIfNeeded() async {
        guard let customerId = pendingStripeCustomerId,
              let subscriptionId = pendingStripeSubscriptionId else { return }

        struct LinkRequest: Encodable {
            let customerId: String
            let subscriptionId: String
        }

        do {
            try await supabase.functions.invoke(
                "link-onboarding-subscription",
                options: FunctionInvokeOptions(body: LinkRequest(
                    customerId: customerId,
                    subscriptionId: subscriptionId
                ))
            )
            clearStripeData()
            print("✅ Stripe subscription linked to user profile")
            NotificationCenter.default.post(name: .subscriptionLinked, object: nil)
        } catch {
            print("❌ Failed to link Stripe subscription: \(error)")
        }
    }

    private static func clearStripeData() {
        UserDefaults.standard.removeObject(forKey: emailKey)
        UserDefaults.standard.removeObject(forKey: customerIdKey)
        UserDefaults.standard.removeObject(forKey: subscriptionIdKey)
    }

    // MARK: - Save

    static func save(procedureName: String, procedureDate: Date) {
        UserDefaults.standard.set(procedureName, forKey: procedureNameKey)
        UserDefaults.standard.set(procedureDate, forKey: procedureDateKey)
        hasCompleted = true
    }

    // MARK: - Apply Post-Auth

    /// Bootstraps weekly check-ins from onboarding data, then clears pending state.
    /// Safe to call multiple times — no-ops if data is already applied or absent.
    @MainActor
    static func applyIfNeeded(to viewModel: JournalViewModel) {
        guard let name = pendingProcedureName, let date = pendingProcedureDate else { return }

        // Derive procedureId the same way the rest of the app does
        let procedureId = name
            .lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: "-")

        // Only bootstrap if no check-ins exist yet for this procedure
        let existing = WeeklyCheckInService.shared.loadCheckIns(for: procedureId)
        guard existing.isEmpty else {
            clearPending()
            return
        }

        let checkIns = WeeklyCheckInService.shared.generateCheckIns(
            procedureId: procedureId,
            procedureName: name,
            startDate: date
        )
        WeeklyCheckInService.shared.saveCheckIns(checkIns)
        Task {
            await WeeklyCheckInService.shared.scheduleNotifications(
                for: checkIns, procedureName: name
            )
        }

        // Pre-fill the "Add Entry" sheet with the procedure name so the user
        // can immediately log their first entry without re-typing it.
        viewModel.pendingProcedureName = name
        // Expose the procedure ID so weekly check-ins show before the first journal entry exists.
        viewModel.bootstrappedProcedureId = procedureId

        clearPending()
    }

    // MARK: - Clear

    private static func clearPending() {
        UserDefaults.standard.removeObject(forKey: procedureNameKey)
        UserDefaults.standard.removeObject(forKey: procedureDateKey)
    }

    /// Full reset — for testing or sign-out scenarios.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: completedKey)
        clearPending()
        clearStripeData()
    }
}
