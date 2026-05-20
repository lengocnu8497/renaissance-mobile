//
//  Analytics.swift
//  Renaissance Mobile
//
//  Thin wrapper around PostHog. All call-sites use Analytics.* and never import PostHog directly,
//  making it trivial to swap or stub the underlying SDK.
//

import Foundation
import PostHog

enum Analytics {

    // MARK: - Lifecycle

    static func setup() {
        let config = PostHogConfig(apiKey: AppConfig.postHogAPIKey, host: AppConfig.postHogHost)
        config.captureApplicationLifecycleEvents = false  // we fire session_start manually
        config.captureScreenViews = false
        #if DEBUG
        config.flushAt = 1
        config.flushIntervalSeconds = 1
        #endif
        PostHogSDK.shared.setup(config)
    }

    static func identify(userId: String) {
        PostHogSDK.shared.identify(userId)
    }

    static func reset() {
        PostHogSDK.shared.reset()
    }

    // MARK: - Session

    static func sessionStart() {
        capture("session_start")
    }

    // MARK: - Onboarding funnel

    static func onboardingStarted() {
        capture("onboarding_started")
    }

    static func onboardingBranchSelected(_ branch: OnboardingBranch) {
        capture("onboarding_branch_selected", properties: ["branch": branch.rawValue])
    }

    static func onboardingStepCompleted(stepName: String, branch: OnboardingBranch?) {
        var props: [String: Any] = ["step_name": stepName]
        if let branch { props["branch"] = branch.rawValue }
        capture("onboarding_step_completed", properties: props)
    }

    static func personalizedTeaserViewed(branch: OnboardingBranch, procedure: String?) {
        var props: [String: Any] = ["branch": branch.rawValue]
        if let procedure { props["procedure"] = procedure }
        capture("personalized_teaser_viewed", properties: props)
    }

    static func softPitchViewed(branch: OnboardingBranch) {
        capture("soft_pitch_viewed", properties: ["branch": branch.rawValue])
    }

    // MARK: - Paywall

    static func paywallViewed(branch: OnboardingBranch?, source: String) {
        var props: [String: Any] = ["source": source]
        if let branch { props["branch"] = branch.rawValue }
        capture("paywall_viewed", properties: props)
    }

    static func paywallDismissed(method: String) {
        capture("paywall_dismissed", properties: ["method": method])
    }

    // MARK: - Subscription

    static func trialStarted(plan: String) {
        capture("trial_started", properties: ["plan": plan])
    }

    static func subscriptionStarted(plan: String) {
        capture("subscription_started", properties: ["plan": plan])
    }

    // MARK: - Ask Rena

    static func askRenaUsed(countPerSession: Int) {
        capture("ask_rena_used", properties: ["count_per_session": countPerSession])
    }

    // MARK: - Journal

    static func journalEntryStarted() {
        capture("journal_entry_started")
    }

    static func journalEntrySaved(
        procedure: String,
        dayNumber: Int,
        hasPhoto: Bool,
        hasNotes: Bool,
        painLevel: Int,
        swellingLevel: Int,
        bruisingLevel: Int,
        rednessLevel: Int,
        entryCount: Int
    ) {
        capture("journal_entry_saved", properties: [
            "procedure": procedure,
            "day_number": dayNumber,
            "has_photo": hasPhoto,
            "has_notes": hasNotes,
            "pain_level": painLevel,
            "swelling_level": swellingLevel,
            "bruising_level": bruisingLevel,
            "redness_level": rednessLevel,
            "entry_count": entryCount
        ])
    }

    // MARK: - Photo Capture

    static func photoCaptureOpened() {
        capture("photo_capture_opened")
    }

    static func photoCaptured(source: String) {
        capture("photo_captured", properties: ["source": source])
    }

    // MARK: - Recovery Plan

    static func recoveryPlanViewed() {
        capture("recovery_plan_viewed")
    }

    static func recoveryPlanUnlockTapped() {
        capture("recovery_plan_unlock_tapped")
    }

    // MARK: - Private

    private static func capture(_ event: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.capture(event, properties: properties)
    }
}
