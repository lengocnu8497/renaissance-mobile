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
    /// Persisted after applyIfNeeded — survives app restarts until the first journal entry is added.
    private static let bootstrappedIdKey   = "rena_bootstrapped_procedure_id"
    private static let bootstrappedNameKey = "rena_bootstrapped_procedure_name"

    // AI personalization context
    private static let genderKey               = "rena_onboarding_gender"
    private static let zipCodeKey              = "rena_onboarding_zip_code"
    private static let ageRangeKey             = "rena_onboarding_age_range"
    private static let raceEthnicityKey        = "rena_onboarding_race_ethnicity"
    private static let aestheticGoalsKey       = "rena_onboarding_aesthetic_goals"
    private static let proceduresOfInterestKey = "rena_onboarding_procedures_of_interest"
    private static let previousProceduresKey   = "rena_onboarding_previous_procedures"
    private static let healthFlagsKey          = "rena_onboarding_health_flags"
    private static let bodyAreasKey            = "rena_onboarding_body_areas"

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

    // MARK: - Persisted Bootstrapped Procedure (survives app restarts)

    static var savedBootstrappedProcedureId: String? {
        UserDefaults.standard.string(forKey: bootstrappedIdKey)
    }

    static var savedBootstrappedProcedureName: String? {
        UserDefaults.standard.string(forKey: bootstrappedNameKey)
    }

    static func saveBootstrappedProcedure(id: String, name: String) {
        UserDefaults.standard.set(id, forKey: bootstrappedIdKey)
        UserDefaults.standard.set(name, forKey: bootstrappedNameKey)
    }

    static func clearBootstrappedProcedure() {
        UserDefaults.standard.removeObject(forKey: bootstrappedIdKey)
        UserDefaults.standard.removeObject(forKey: bootstrappedNameKey)
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

    // MARK: - Pending User Context (AI personalization)

    static var pendingGender: String? { UserDefaults.standard.string(forKey: genderKey) }
    static var pendingZipCode: String? { UserDefaults.standard.string(forKey: zipCodeKey) }
    static var pendingAgeRange: String? { UserDefaults.standard.string(forKey: ageRangeKey) }
    static var pendingRaceEthnicity: String? { UserDefaults.standard.string(forKey: raceEthnicityKey) }
    static var pendingAestheticGoals: [String] {
        UserDefaults.standard.stringArray(forKey: aestheticGoalsKey) ?? []
    }
    static var pendingProceduresOfInterest: [String] {
        UserDefaults.standard.stringArray(forKey: proceduresOfInterestKey) ?? []
    }
    static var pendingPreviousProcedures: [String] {
        UserDefaults.standard.stringArray(forKey: previousProceduresKey) ?? []
    }
    static var pendingHealthFlags: [String] {
        UserDefaults.standard.stringArray(forKey: healthFlagsKey) ?? []
    }
    static var pendingBodyAreas: [String] {
        UserDefaults.standard.stringArray(forKey: bodyAreasKey) ?? []
    }

    static func saveUserContext(
        gender: String?,
        zipCode: String?,
        ageRange: String?,
        raceEthnicity: String?,
        aestheticGoals: [String],
        proceduresOfInterest: [String],
        previousProcedures: [String],
        healthFlags: [String],
        bodyAreas: [String]
    ) {
        let ud = UserDefaults.standard
        if let v = gender { ud.set(v, forKey: genderKey) }
        if let v = zipCode, !v.isEmpty { ud.set(v, forKey: zipCodeKey) }
        if let v = ageRange { ud.set(v, forKey: ageRangeKey) }
        if let v = raceEthnicity { ud.set(v, forKey: raceEthnicityKey) }
        ud.set(aestheticGoals, forKey: aestheticGoalsKey)
        ud.set(proceduresOfInterest, forKey: proceduresOfInterestKey)
        ud.set(previousProcedures, forKey: previousProceduresKey)
        ud.set(healthFlags, forKey: healthFlagsKey)
        ud.set(bodyAreas, forKey: bodyAreasKey)
    }

    /// Writes any pending onboarding user-context to the Supabase profile.
    /// Safe to call on every sign-in — no-ops if nothing is pending.
    static func syncUserContextIfNeeded(using profileService: UserProfileService) async {
        let hasData = pendingGender != nil
            || pendingZipCode != nil
            || pendingAgeRange != nil
            || pendingRaceEthnicity != nil
            || !pendingAestheticGoals.isEmpty
            || !pendingProceduresOfInterest.isEmpty
            || !pendingPreviousProcedures.isEmpty
            || !pendingHealthFlags.isEmpty
            || !pendingBodyAreas.isEmpty

        guard hasData else { return }

        do {
            var profile = try await profileService.getUserProfile()
            if let v = pendingGender { profile.gender = v }
            if let v = pendingZipCode { profile.zipCode = v }
            if let v = pendingAgeRange { profile.ageRange = v }
            if let v = pendingRaceEthnicity { profile.raceEthnicity = v }
            if !pendingAestheticGoals.isEmpty { profile.aestheticGoals = pendingAestheticGoals }
            if !pendingProceduresOfInterest.isEmpty { profile.proceduresOfInterest = pendingProceduresOfInterest }
            if !pendingPreviousProcedures.isEmpty { profile.previousProcedures = pendingPreviousProcedures }
            if !pendingHealthFlags.isEmpty { profile.healthFlags = pendingHealthFlags }
            if !pendingBodyAreas.isEmpty { profile.bodyAreasOfInterest = pendingBodyAreas }
            _ = try await profileService.updateUserProfile(profile)
            clearUserContext()
            print("✅ Onboarding user context synced to profile")
        } catch {
            print("❌ Failed to sync onboarding user context: \(error)")
        }
    }

    private static func clearUserContext() {
        let ud = UserDefaults.standard
        [genderKey, zipCodeKey, ageRangeKey, raceEthnicityKey,
         aestheticGoalsKey, proceduresOfInterestKey, previousProceduresKey,
         healthFlagsKey, bodyAreasKey].forEach { ud.removeObject(forKey: $0) }
    }

    // MARK: - Save

    static func save(procedureName: String, procedureDate: Date) {
        UserDefaults.standard.set(procedureName, forKey: procedureNameKey)
        UserDefaults.standard.set(procedureDate, forKey: procedureDateKey)
        hasCompleted = true
    }

    // MARK: - Apply Post-Auth

    /// Restores or applies onboarding procedure data so the app can render recovery state
    /// before the first journal entry is created.
    @MainActor
    static func applyIfNeeded(to viewModel: JournalViewModel) async {
        guard let name = pendingProcedureName, let date = pendingProcedureDate else {
            if let savedId = savedBootstrappedProcedureId {
                viewModel.bootstrappedProcedureId   = savedId
                viewModel.bootstrappedProcedureName = savedBootstrappedProcedureName
            }
            return
        }

        let procedureId = name
            .lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: "-")

        viewModel.pendingProcedureName      = name
        viewModel.bootstrappedProcedureId   = procedureId
        viewModel.bootstrappedProcedureName = name

        saveBootstrappedProcedure(id: procedureId, name: name)
        await viewModel.bootstrapWeeklyState(
            procedureId: procedureId,
            procedureName: name,
            startDate: date
        )
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
        clearBootstrappedProcedure()
        clearUserContext()
    }
}
