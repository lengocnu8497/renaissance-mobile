//
//  FreeUsageStore.swift
//  Renaissance Mobile
//
//  Local tracking for the free daily AI chat allowance and session-2 upgrade banner.
//  The authoritative limit is enforced server-side in the chat-ai Edge Function;
//  this store drives display-only state (questions remaining, banner timing).
//

import Foundation

enum FreeUsageStore {
    static let dailyLimit = 3

    private static let defaults = UserDefaults.standard
    private static let usedKey      = "rena_free_questions_used"
    private static let dateKey      = "rena_free_questions_date"
    private static let foregroundKey = "rena_free_foreground_count"

    // MARK: - Daily question counter

    /// Consume one free question. Returns false if the daily limit is already reached.
    @discardableResult
    static func consumeDailyQuestion() -> Bool {
        resetIfNewDay()
        let used = defaults.integer(forKey: usedKey)
        guard used < dailyLimit else { return false }
        defaults.set(used + 1, forKey: usedKey)
        return true
    }

    static var questionsRemaining: Int {
        resetIfNewDay()
        return max(0, dailyLimit - defaults.integer(forKey: usedKey))
    }

    // MARK: - Session / foreground tracking

    /// Call once each time the app returns to the foreground for a free-tier user.
    static func recordForeground() {
        defaults.set(defaults.integer(forKey: foregroundKey) + 1, forKey: foregroundKey)
    }

    /// Number of foreground events recorded since the user tapped "Maybe later".
    static var foregroundCount: Int {
        defaults.integer(forKey: foregroundKey)
    }

    // MARK: - Reset

    static func reset() {
        defaults.removeObject(forKey: usedKey)
        defaults.removeObject(forKey: dateKey)
        defaults.removeObject(forKey: foregroundKey)
    }

    // MARK: - Private

    private static func resetIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        if let stored = defaults.object(forKey: dateKey) as? Date,
           Calendar.current.isDate(stored, inSameDayAs: today) { return }
        defaults.set(0, forKey: usedKey)
        defaults.set(today, forKey: dateKey)
    }
}
