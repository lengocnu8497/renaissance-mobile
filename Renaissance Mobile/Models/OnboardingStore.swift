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
    static let subscriptionStatusChanged = Notification.Name("rena_subscription_status_changed")
    static let onboardingStateChanged = Notification.Name("rena_onboarding_state_changed")
}

enum OnboardingPresentationStatus: String, Equatable {
    case pending
    case completed
}

enum OnboardingCompletionReason: String, Equatable {
    case purchased
    case maybeLater
    case restoredAccess
}

struct OnboardingPresentationDecision: Equatable {
    let userID: String?
    let status: OnboardingPresentationStatus
    let completionReason: OnboardingCompletionReason?
    let hasActiveSubscription: Bool
    let hasBackendPremiumAccess: Bool?
    let shouldPresent: Bool
    let trigger: String
}

enum AcquisitionSource: String, CaseIterable, Identifiable {
    case instagram = "instagram"
    case tiktok = "tiktok"
    case googleSearch = "google_search"
    case friendOrFamily = "friend_or_family"
    case doctorOrClinic = "doctor_or_clinic"
    case appStoreSearch = "app_store_search"
    case pressOrBlog = "press_or_blog"
    case other = "other"

    var id: String { rawValue }

    static let onboardingChoices: [AcquisitionSource] = [
        .instagram,
        .tiktok,
        .googleSearch,
        .appStoreSearch,
        .friendOrFamily,
        .doctorOrClinic,
        .other,
    ]

    var displayName: String {
        switch self {
        case .instagram:
            return "Instagram"
        case .tiktok:
            return "TikTok"
        case .googleSearch:
            return "Google Search"
        case .friendOrFamily:
            return "Friend or Family"
        case .doctorOrClinic:
            return "Doctor or Clinic"
        case .appStoreSearch:
            return "App Store Search"
        case .pressOrBlog:
            return "Press or Blog"
        case .other:
            return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .instagram:
            return "camera"
        case .tiktok:
            return "play.rectangle"
        case .googleSearch:
            return "magnifyingglass"
        case .friendOrFamily:
            return "person.2"
        case .doctorOrClinic:
            return "cross.case"
        case .appStoreSearch:
            return "app.badge"
        case .pressOrBlog:
            return "newspaper"
        case .other:
            return "ellipsis.circle"
        }
    }
}

struct OnboardingStore {

    // MARK: - UserDefaults Keys

    private static let completedKey        = "rena_onboarding_completed"
    private static let statusKey           = "rena_onboarding_status"
    private static let completionReasonKey = "rena_onboarding_completion_reason"
    private static let completedAtKey      = "rena_onboarding_completed_at"
    private static let procedureNameKey  = "rena_onboarding_procedure_name"
    private static let procedureDateKey  = "rena_onboarding_procedure_date"
    private static let emailKey          = "rena_onboarding_email"
    private static let subscriptionTierKey = "rena_onboarding_subscription_tier"
    private static let acquisitionSourceKey = "rena_onboarding_acquisition_source"
    private static let shouldShowFeedbackKey = "rena_onboarding_should_show_feedback"
    private static let feedbackCompletedKey = "rena_onboarding_feedback_completed"
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

    private static func userScopedKey(_ key: String) -> String {
        guard let userId = supabase.auth.currentUser?.id.uuidString else { return key }
        return "\(key)_\(userId)"
    }

    private static func removeUserScopedValue(forKey key: String) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: userScopedKey(key))
        defaults.removeObject(forKey: key)
        ProtectedLocalStore.remove(forKey: userScopedKey(key))
        ProtectedLocalStore.remove(forKey: key)
    }

    private static func protectedString(forKey key: String) -> String? {
        ProtectedLocalStore.load(String.self, forKey: key)
    }

    private static func protectedDate(forKey key: String) -> Date? {
        ProtectedLocalStore.load(Date.self, forKey: key)
    }

    private static func protectedArray(forKey key: String) -> [String] {
        ProtectedLocalStore.load([String].self, forKey: key) ?? []
    }

    private static func setProtected<Value: Codable>(_ value: Value, forKey key: String) {
        try? ProtectedLocalStore.save(value, forKey: key)
    }

    private static func log(_ event: String, details: [String: String?] = [:]) {
        let payload = details
            .compactMap { key, value -> String? in
                guard let value else { return nil }
                return "\(key)=\(value)"
            }
            .sorted()
            .joined(separator: " ")

        if payload.isEmpty {
            print("[OnboardingStore] \(event)")
        } else {
            print("[OnboardingStore] \(event) \(payload)")
        }
    }

    private static func currentUserIDString() -> String? {
        supabase.auth.currentUser?.id.uuidString
    }

    private static func persistedStatus(for defaults: UserDefaults = .standard) -> OnboardingPresentationStatus {
        let scopedStatusKey = userScopedKey(statusKey)

        if let rawValue = defaults.string(forKey: scopedStatusKey),
           let status = OnboardingPresentationStatus(rawValue: rawValue) {
            return status
        }

        if defaults.bool(forKey: scopedStatusKey) || defaults.bool(forKey: userScopedKey(completedKey)) {
            return .completed
        }

        return .pending
    }

    private static func setPresentationStatus(
        _ status: OnboardingPresentationStatus,
        reason: OnboardingCompletionReason?,
        source: String,
        notifyObservers: Bool = true
    ) {
        let defaults = UserDefaults.standard
        let scopedStatusKey = userScopedKey(statusKey)
        let scopedCompletedKey = userScopedKey(completedKey)
        let scopedCompletionReasonKey = userScopedKey(completionReasonKey)
        let scopedCompletedAtKey = userScopedKey(completedAtKey)

        defaults.set(status.rawValue, forKey: scopedStatusKey)
        defaults.removeObject(forKey: statusKey)

        switch status {
        case .completed:
            defaults.set(true, forKey: scopedCompletedKey)
            defaults.removeObject(forKey: completedKey)
            if let reason {
                defaults.set(reason.rawValue, forKey: scopedCompletionReasonKey)
                defaults.removeObject(forKey: completionReasonKey)
            }
            defaults.set(Date(), forKey: scopedCompletedAtKey)
            defaults.removeObject(forKey: completedAtKey)
        case .pending:
            defaults.removeObject(forKey: scopedCompletedKey)
            defaults.removeObject(forKey: completedKey)
            defaults.removeObject(forKey: scopedCompletionReasonKey)
            defaults.removeObject(forKey: completionReasonKey)
            defaults.removeObject(forKey: scopedCompletedAtKey)
            defaults.removeObject(forKey: completedAtKey)
        }

        log(
            "store.transition",
            details: [
                "source": source,
                "userID": currentUserIDString(),
                "status": status.rawValue,
                "completionReason": reason?.rawValue
            ]
        )

        if notifyObservers {
            NotificationCenter.default.post(name: .onboardingStateChanged, object: nil)
        }
    }

    // MARK: - Completion Flag

    static var hasCompleted: Bool {
        get { presentationStatus == .completed }
        set {
            if newValue {
                completeOnboarding(reason: .restoredAccess, source: "legacySetter")
            } else {
                markOnboardingPending(source: "legacySetter")
            }
        }
    }

    static var presentationStatus: OnboardingPresentationStatus {
        persistedStatus()
    }

    static var completionReason: OnboardingCompletionReason? {
        let defaults = UserDefaults.standard
        let scopedReasonKey = userScopedKey(completionReasonKey)

        guard let rawValue = defaults.string(forKey: scopedReasonKey) else {
            return nil
        }

        return OnboardingCompletionReason(rawValue: rawValue)
    }

    static var shouldPresentOnboarding: Bool {
        presentationStatus != .completed
    }

    static func completeOnboarding(reason: OnboardingCompletionReason, source: String) {
        log(
            "store.completeOnboarding",
            details: [
                "source": source,
                "userID": currentUserIDString(),
                "reason": reason.rawValue
            ]
        )
        setPresentationStatus(.completed, reason: reason, source: source)
    }

    static func markOnboardingPending(source: String) {
        setPresentationStatus(.pending, reason: nil, source: source)
    }

    @MainActor
    static func resolvePresentationDecision(
        trigger: String,
        profileService: UserProfileService
    ) async -> OnboardingPresentationDecision {
        await resolvePresentationDecision(
            trigger: trigger,
            using: .shared,
            profileService: profileService
        )
    }

    @MainActor
    static func resolvePresentationDecision(
        trigger: String,
        using subscriptionStore: SubscriptionStore,
        profileService: UserProfileService
    ) async -> OnboardingPresentationDecision {
        log(
            "store.load",
            details: [
                "trigger": trigger,
                "userID": currentUserIDString(),
                "status": presentationStatus.rawValue,
                "completionReason": completionReason?.rawValue
            ]
        )

        if !shouldPresentOnboarding {
            let decision = OnboardingPresentationDecision(
                userID: currentUserIDString(),
                status: presentationStatus,
                completionReason: completionReason,
                hasActiveSubscription: subscriptionStore.hasActiveSubscription,
                hasBackendPremiumAccess: nil,
                shouldPresent: false,
                trigger: trigger
            )
            logDecision(decision)
            return decision
        }

        if subscriptionStore.hasActiveSubscription {
            completeOnboarding(reason: .restoredAccess, source: "\(trigger):cachedSubscription")
            let decision = OnboardingPresentationDecision(
                userID: currentUserIDString(),
                status: presentationStatus,
                completionReason: completionReason,
                hasActiveSubscription: true,
                hasBackendPremiumAccess: nil,
                shouldPresent: false,
                trigger: trigger
            )
            logDecision(decision)
            return decision
        }

        await subscriptionStore.prepare()

        if subscriptionStore.hasActiveSubscription {
            completeOnboarding(reason: .restoredAccess, source: "\(trigger):preparedSubscription")
            let decision = OnboardingPresentationDecision(
                userID: currentUserIDString(),
                status: presentationStatus,
                completionReason: completionReason,
                hasActiveSubscription: true,
                hasBackendPremiumAccess: nil,
                shouldPresent: false,
                trigger: trigger
            )
            logDecision(decision)
            return decision
        }

        do {
            let profile = try await profileService.getUserProfile()
            let hasBackendPremiumAccess = SubscriptionAccessEvaluator.hasBackendPremiumAccess(profile)

            if hasBackendPremiumAccess {
                completeOnboarding(reason: .restoredAccess, source: "\(trigger):backendPremium")
            }

            let decision = OnboardingPresentationDecision(
                userID: currentUserIDString(),
                status: presentationStatus,
                completionReason: completionReason,
                hasActiveSubscription: subscriptionStore.hasActiveSubscription,
                hasBackendPremiumAccess: hasBackendPremiumAccess,
                shouldPresent: !hasBackendPremiumAccess && shouldPresentOnboarding,
                trigger: trigger
            )
            logDecision(decision)
            return decision
        } catch {
            log(
                "store.profileFetchFailed",
                details: [
                    "trigger": trigger,
                    "userID": currentUserIDString(),
                    "error": error.localizedDescription
                ]
            )

            let decision = OnboardingPresentationDecision(
                userID: currentUserIDString(),
                status: presentationStatus,
                completionReason: completionReason,
                hasActiveSubscription: subscriptionStore.hasActiveSubscription,
                hasBackendPremiumAccess: nil,
                shouldPresent: shouldPresentOnboarding,
                trigger: trigger
            )
            logDecision(decision)
            return decision
        }
    }

    private static func logDecision(_ decision: OnboardingPresentationDecision) {
        log(
            "store.computeShouldPresent",
            details: [
                "trigger": decision.trigger,
                "userID": decision.userID,
                "status": decision.status.rawValue,
                "completionReason": decision.completionReason?.rawValue,
                "hasActiveSubscription": String(decision.hasActiveSubscription),
                "hasBackendPremiumAccess": decision.hasBackendPremiumAccess.map { String(describing: $0) },
                "shouldPresent": String(decision.shouldPresent)
            ]
        )
    }

    // MARK: - Pending Procedure Data

    static var pendingProcedureName: String? {
        protectedString(forKey: userScopedKey(procedureNameKey))
    }

    static var pendingProcedureDate: Date? {
        protectedDate(forKey: userScopedKey(procedureDateKey))
    }

    // MARK: - Pending Account Data
    static var pendingEmail: String? {
        protectedString(forKey: emailKey)
    }

    static var pendingSubscriptionTier: SubscriptionTier? {
        guard let rawValue = protectedString(forKey: subscriptionTierKey) else {
            return nil
        }
        return SubscriptionTier(rawValue: rawValue)
    }

    static var pendingAcquisitionSource: AcquisitionSource? {
        guard let rawValue = protectedString(forKey: userScopedKey(acquisitionSourceKey)) else {
            return nil
        }
        return AcquisitionSource(rawValue: rawValue)
    }

    static var shouldPresentPostOnboardingFeedback: Bool {
        UserDefaults.standard.bool(forKey: userScopedKey(shouldShowFeedbackKey))
            && !UserDefaults.standard.bool(forKey: userScopedKey(feedbackCompletedKey))
    }

    // MARK: - Persisted Bootstrapped Procedure (survives app restarts)

    static var savedBootstrappedProcedureId: String? {
        protectedString(forKey: userScopedKey(bootstrappedIdKey))
    }

    static var savedBootstrappedProcedureName: String? {
        protectedString(forKey: userScopedKey(bootstrappedNameKey))
    }

    static func saveBootstrappedProcedure(id: String, name: String) {
        setProtected(id, forKey: userScopedKey(bootstrappedIdKey))
        setProtected(name, forKey: userScopedKey(bootstrappedNameKey))
    }

    static func clearBootstrappedProcedure() {
        removeUserScopedValue(forKey: bootstrappedIdKey)
        removeUserScopedValue(forKey: bootstrappedNameKey)
    }

    static func savePendingEmail(_ email: String) {
        setProtected(email, forKey: emailKey)
    }

    static func savePendingSubscriptionTier(_ tier: SubscriptionTier) {
        setProtected(tier.rawValue, forKey: subscriptionTierKey)
    }

    static func savePendingAcquisitionSource(_ source: AcquisitionSource) {
        setProtected(source.rawValue, forKey: userScopedKey(acquisitionSourceKey))
    }

    static func preparePostOnboardingFeedback() {
        UserDefaults.standard.set(true, forKey: userScopedKey(shouldShowFeedbackKey))
        UserDefaults.standard.set(false, forKey: userScopedKey(feedbackCompletedKey))
    }

    static func completePostOnboardingFeedback() {
        UserDefaults.standard.set(false, forKey: userScopedKey(shouldShowFeedbackKey))
        UserDefaults.standard.set(true, forKey: userScopedKey(feedbackCompletedKey))
    }

    /// Refreshes any App Store entitlement after auth and mirrors it to the backend.
    @MainActor
    static func linkSubscriptionIfNeeded() async {
        await SubscriptionStore.shared.refreshEntitlementsAndSync()
        clearPendingEmail()
        NotificationCenter.default.post(name: .subscriptionLinked, object: nil)
    }

    @MainActor
    static func completePendingSubscriptionPurchaseIfNeeded() async -> SubscriptionPurchaseOutcome? {
        guard let tier = pendingSubscriptionTier else { return nil }

        let outcome = await SubscriptionStore.shared.purchase(tier)
        clearPendingSubscriptionTier()
        return outcome
    }

    @MainActor
    static func finalizeAuthenticatedOnboarding(
        using profileService: UserProfileService
    ) async -> SubscriptionPurchaseOutcome? {
        await syncUserContextIfNeeded(using: profileService)
        await syncAttributionIfNeeded(using: profileService)
        let purchaseOutcome = await completePendingSubscriptionPurchaseIfNeeded()
        await linkSubscriptionIfNeeded()
        return purchaseOutcome
    }

    private static func clearPendingEmail() {
        ProtectedLocalStore.remove(forKey: emailKey)
    }

    private static func clearPendingSubscriptionTier() {
        ProtectedLocalStore.remove(forKey: subscriptionTierKey)
    }

    private static func clearPendingAcquisitionSource() {
        removeUserScopedValue(forKey: acquisitionSourceKey)
    }

    // MARK: - Pending User Context (AI personalization)

    static var pendingGender: String? { protectedString(forKey: userScopedKey(genderKey)) }
    static var pendingZipCode: String? { protectedString(forKey: userScopedKey(zipCodeKey)) }
    static var pendingAgeRange: String? { protectedString(forKey: userScopedKey(ageRangeKey)) }
    static var pendingRaceEthnicity: String? { protectedString(forKey: userScopedKey(raceEthnicityKey)) }
    static var pendingAestheticGoals: [String] {
        protectedArray(forKey: userScopedKey(aestheticGoalsKey))
    }
    static var pendingProceduresOfInterest: [String] {
        protectedArray(forKey: userScopedKey(proceduresOfInterestKey))
    }
    static var pendingPreviousProcedures: [String] {
        protectedArray(forKey: userScopedKey(previousProceduresKey))
    }
    static var pendingHealthFlags: [String] {
        protectedArray(forKey: userScopedKey(healthFlagsKey))
    }
    static var pendingBodyAreas: [String] {
        protectedArray(forKey: userScopedKey(bodyAreasKey))
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
        if let v = gender { setProtected(v, forKey: userScopedKey(genderKey)) }
        if let v = zipCode, !v.isEmpty { setProtected(v, forKey: userScopedKey(zipCodeKey)) }
        if let v = ageRange { setProtected(v, forKey: userScopedKey(ageRangeKey)) }
        if let v = raceEthnicity { setProtected(v, forKey: userScopedKey(raceEthnicityKey)) }
        setProtected(aestheticGoals, forKey: userScopedKey(aestheticGoalsKey))
        setProtected(proceduresOfInterest, forKey: userScopedKey(proceduresOfInterestKey))
        setProtected(previousProcedures, forKey: userScopedKey(previousProceduresKey))
        setProtected(healthFlags, forKey: userScopedKey(healthFlagsKey))
        setProtected(bodyAreas, forKey: userScopedKey(bodyAreasKey))
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

    static func syncAttributionIfNeeded(using profileService: UserProfileService) async {
        guard let source = pendingAcquisitionSource else { return }

        let formatter = ISO8601DateFormatter()
        let metadataUpdates: [String: AnyCodable] = [
            "acquisition_source": AnyCodable(source.rawValue),
            "acquisition_source_label": AnyCodable(source.displayName),
            "acquisition_source_recorded_at": AnyCodable(formatter.string(from: Date()))
        ]

        do {
            _ = try await profileService.updateMetadata(metadataUpdates)
            clearPendingAcquisitionSource()
            print("✅ Onboarding attribution synced to profile metadata")
        } catch {
            print("❌ Failed to sync onboarding attribution: \(error)")
        }
    }

    private static func clearUserContext() {
        [genderKey, zipCodeKey, ageRangeKey, raceEthnicityKey,
         aestheticGoalsKey, proceduresOfInterestKey, previousProceduresKey,
         healthFlagsKey, bodyAreasKey].forEach { removeUserScopedValue(forKey: $0) }
    }

    // MARK: - Save

    static func save(procedureName: String, procedureDate: Date) {
        setProtected(procedureName, forKey: userScopedKey(procedureNameKey))
        setProtected(procedureDate, forKey: userScopedKey(procedureDateKey))
    }

    // MARK: - Apply Post-Auth

    /// Restores or applies onboarding procedure data so the app can render recovery state
    /// before the first journal entry is created.
    @MainActor
    static func applyIfNeeded(to viewModel: JournalViewModel) async {
        guard hasCompleted else { return }

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
        removeUserScopedValue(forKey: procedureNameKey)
        removeUserScopedValue(forKey: procedureDateKey)
    }

    /// Full reset — for testing or sign-out scenarios.
    static func reset() {
        removeUserScopedValue(forKey: completedKey)
        removeUserScopedValue(forKey: statusKey)
        removeUserScopedValue(forKey: completionReasonKey)
        removeUserScopedValue(forKey: completedAtKey)
        clearPending()
        clearPendingEmail()
        clearPendingSubscriptionTier()
        clearPendingAcquisitionSource()
        removeUserScopedValue(forKey: shouldShowFeedbackKey)
        removeUserScopedValue(forKey: feedbackCompletedKey)
        clearBootstrappedProcedure()
        clearUserContext()
        NotificationCenter.default.post(name: .onboardingStateChanged, object: nil)
    }
}
