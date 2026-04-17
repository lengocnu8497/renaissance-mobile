//
//  OnboardingReviewPromptPolicy.swift
//  Renaissance Mobile
//

import Foundation

enum OnboardingReviewPromptPolicy {
    static func shouldQueuePrompt(hasQueuedPromptInSession: Bool) -> Bool {
        !hasQueuedPromptInSession
    }
}
