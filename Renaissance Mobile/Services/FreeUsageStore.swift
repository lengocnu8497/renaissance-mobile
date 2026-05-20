//
//  FreeUsageStore.swift
//  Renaissance Mobile
//
//  Local tracking for the free monthly AI chat allowance and session-2 upgrade banner.
//  The authoritative limit is enforced server-side in the chat-ai Edge Function;
//  this store drives display-only state (questions remaining, banner timing).
//

import Foundation

enum FreeUsageStore {
    static let monthlyLimit = 3

    private static let defaults = UserDefaults.standard
    private static let usedKey       = "rena_free_questions_used"
    private static let monthKey      = "rena_free_questions_month"
    private static let foregroundKey = "rena_free_foreground_count"

    // MARK: - Monthly question counter

    /// Consume one free question. Returns false if the monthly limit is already reached.
    @discardableResult
    static func consumeMonthlyQuestion() -> Bool {
        resetIfNewMonth()
        let used = defaults.integer(forKey: usedKey)
        guard used < monthlyLimit else { return false }
        defaults.set(used + 1, forKey: usedKey)
        return true
    }

    static var questionsRemaining: Int {
        resetIfNewMonth()
        return max(0, monthlyLimit - defaults.integer(forKey: usedKey))
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
        defaults.removeObject(forKey: monthKey)
        defaults.removeObject(forKey: foregroundKey)
    }

    // MARK: - Private

    private static func resetIfNewMonth() {
        let cal = Calendar.current
        let now = Date()
        let currentMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        if let stored = defaults.object(forKey: monthKey) as? Date,
           cal.isDate(stored, equalTo: currentMonthStart, toGranularity: .month) { return }
        defaults.set(0, forKey: usedKey)
        defaults.set(currentMonthStart, forKey: monthKey)
    }
}
