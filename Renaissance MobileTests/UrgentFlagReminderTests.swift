//
//  UrgentFlagReminderTests.swift
//  Renaissance MobileTests
//
//  Tests for JournalViewModel.urgentFlagNeedsReminder(insights:upcomingReminders:)
//
//  The function must return:
//    true  — urgent flag exists AND no upcoming reminder is scheduled for that procedure
//    false — any other combination (no urgent flag, OR reminder already exists)
//

import XCTest
@testable import Renaissance_Mobile

final class UrgentFlagReminderTests: XCTestCase {

    // MARK: - Helpers

    private func urgentFlag(metric: String? = "Bruising") -> InsightFlag {
        InsightFlag(severity: .urgent, message: "Bruising is unusually high.", metric: metric)
    }

    private func warningFlag() -> InsightFlag {
        InsightFlag(severity: .warning, message: "Swelling persists.", metric: "Swelling")
    }

    private func infoFlag() -> InsightFlag {
        InsightFlag(severity: .info, message: "Sleep elevated.", metric: nil)
    }

    // MARK: - Happy Path: prompt SHOULD show

    /// Baseline: one urgent flag, zero reminders → show prompt.
    func testUrgentFlag_noReminders_returnsTrue() {
        let insights = RecoveryInsights.stub(flags: [urgentFlag()])
        XCTAssertTrue(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: []))
    }

    /// Multiple flags including one urgent, zero reminders → show prompt.
    func testMultipleFlagsIncludingUrgent_noReminders_returnsTrue() {
        let insights = RecoveryInsights.stub(flags: [warningFlag(), infoFlag(), urgentFlag()])
        XCTAssertTrue(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: []))
    }

    /// Urgent flag + reminder exists for a DIFFERENT procedure → show prompt.
    func testUrgentFlag_reminderExistsForDifferentProcedure_returnsTrue() {
        let insights = RecoveryInsights.stub(procedureName: "Rhinoplasty", flags: [urgentFlag()])
        let otherReminder = TreatmentReminder.stub(procedureName: "Botox")
        XCTAssertTrue(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: [otherReminder]))
    }

    /// Multiple urgent flags, zero reminders → show prompt (each flag independently qualifies).
    func testMultipleUrgentFlags_noReminders_returnsTrue() {
        let flags = [urgentFlag(metric: "Bruising"), urgentFlag(metric: "Swelling")]
        let insights = RecoveryInsights.stub(flags: flags)
        XCTAssertTrue(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: []))
    }

    /// Urgent flag + empty insights encouragements/nextSteps (unrelated fields) → still shows.
    func testUrgentFlag_withOtherInsightFields_returnsTrue() {
        let insights = RecoveryInsights.stub(
            flags: [urgentFlag()],
            encouragements: ["Great progress!"],
            nextSteps: "Elevate your head."
        )
        XCTAssertTrue(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: []))
    }

    // MARK: - Non-Happy Paths: prompt should NOT show

    /// No flags at all → never show prompt.
    func testNoFlags_returnsfalse() {
        let insights = RecoveryInsights.stub(flags: [])
        XCTAssertFalse(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: []))
    }

    /// Only .warning flags → don't show prompt.
    func testOnlyWarningFlags_returnsFalse() {
        let insights = RecoveryInsights.stub(flags: [warningFlag()])
        XCTAssertFalse(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: []))
    }

    /// Only .info flags → don't show prompt.
    func testOnlyInfoFlags_returnsFalse() {
        let insights = RecoveryInsights.stub(flags: [infoFlag()])
        XCTAssertFalse(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: []))
    }

    /// Only .warning + .info flags (no urgent) → don't show prompt.
    func testWarningAndInfoFlagsOnly_returnsFalse() {
        let insights = RecoveryInsights.stub(flags: [warningFlag(), infoFlag()])
        XCTAssertFalse(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: []))
    }

    /// Urgent flag + active reminder for the SAME procedure (exact match) → don't show prompt.
    func testUrgentFlag_reminderExistsForSameProcedure_returnsFalse() {
        let insights = RecoveryInsights.stub(procedureName: "Rhinoplasty", flags: [urgentFlag()])
        let reminder = TreatmentReminder.stub(procedureName: "Rhinoplasty")
        XCTAssertFalse(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: [reminder]))
    }

    /// Case-insensitive match: insights "Botox" vs reminder "botox" → treated as same procedure.
    func testUrgentFlag_caseInsensitiveMatch_returnsFalse() {
        let insights = RecoveryInsights.stub(procedureName: "Botox", flags: [urgentFlag()])
        let reminder = TreatmentReminder.stub(procedureName: "botox")
        XCTAssertFalse(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: [reminder]))
    }

    /// Case-insensitive match: insights "botox" vs reminder "BOTOX" → treated as same procedure.
    func testUrgentFlag_caseInsensitiveMatchUppercase_returnsFalse() {
        let insights = RecoveryInsights.stub(procedureName: "botox", flags: [urgentFlag()])
        let reminder = TreatmentReminder.stub(procedureName: "BOTOX")
        XCTAssertFalse(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: [reminder]))
    }

    /// Multiple reminders for different procedures + one matching → don't show prompt.
    func testUrgentFlag_multipleRemindersOneMatching_returnsFalse() {
        let insights = RecoveryInsights.stub(procedureName: "Rhinoplasty", flags: [urgentFlag()])
        let reminders = [
            TreatmentReminder.stub(procedureName: "Botox"),
            TreatmentReminder.stub(procedureName: "Rhinoplasty"),
            TreatmentReminder.stub(procedureName: "Lip Filler")
        ]
        XCTAssertFalse(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: reminders))
    }

    // MARK: - Edge Cases

    /// Retreatment-kind reminder (not just follow-up) also counts as "reminder exists".
    func testUrgentFlag_retreatmentReminderExistsForSameProcedure_returnsFalse() {
        let insights = RecoveryInsights.stub(procedureName: "Botox", flags: [urgentFlag()])
        let reminder = TreatmentReminder.stub(procedureName: "Botox", kind: .retreatment)
        XCTAssertFalse(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: [reminder]))
    }

    /// Insights with no flags and no reminders → false (no urgent flag = no prompt regardless).
    func testNoFlagsNoReminders_returnsFalse() {
        let insights = RecoveryInsights.stub(flags: [])
        XCTAssertFalse(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: []))
    }

    /// Trend = .concerning alone (no urgent flag) is NOT enough to trigger prompt.
    func testConcerningTrend_noUrgentFlag_returnsFalse() {
        let insights = RecoveryInsights.stub(trend: .concerning, flags: [warningFlag()])
        XCTAssertFalse(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: []))
    }

    /// Trend = .concerning WITH urgent flag + no reminder → true.
    func testConcerningTrend_withUrgentFlag_noReminder_returnsTrue() {
        let insights = RecoveryInsights.stub(trend: .concerning, flags: [urgentFlag()])
        XCTAssertTrue(JournalViewModel.urgentFlagNeedsReminder(insights: insights, upcomingReminders: []))
    }
}
