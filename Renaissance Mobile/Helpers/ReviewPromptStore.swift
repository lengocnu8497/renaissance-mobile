//
//  ReviewPromptStore.swift
//  Renaissance Mobile
//

import Foundation

struct ReviewPromptStore {
    private static let automaticReviewRequestedKey = "rena_review_automatic_requested"

    static var hasRequestedAutomaticReview: Bool {
        UserDefaults.standard.bool(forKey: automaticReviewRequestedKey)
    }

    static var shouldRequestAutomaticReview: Bool {
        !hasRequestedAutomaticReview
    }

    static func markAutomaticReviewRequested() {
        UserDefaults.standard.set(true, forKey: automaticReviewRequestedKey)
    }
}
