//
//  PhotoJournalView.swift
//  Renaissance Mobile
//

import SwiftUI
import UserNotifications
import Supabase

// MARK: - Design tokens — sourced directly from rena-journal-ai-insights.html

private enum J {
    static let pageBg        = Color(hex: "#F6F7F2")
    static let primary       = Color(hex: "#516048")   // green accent for actions / progress
    static let gradA         = Color(hex: "#B07B7A")
    static let gradMid       = Color(hex: "#C4929A")
    static let gradB         = Color(hex: "#D8AAA8")
    static let accent        = Color(hex: "#B07B7A")   // pink emphasis
    static let roseSoft      = Color(hex: "#F1DDDA")
    static let textHi        = Color(hex: "#1F261D")
    static let textLo        = Color(hex: "#687064")
    static let card          = Color(hex: "#EDF1E8")
    static let cardWhite     = Color.white
    static let border        = Color.black.opacity(0.05)
    // AI card tints
    static let concernTint   = Color(hex: "#F7E6E3")
    static let reminderTint  = Color(hex: "#F4E8E7")
    static let positiveTint  = Color(hex: "#EDF1E8")
    // Dimmed primary (badges, arrow buttons)
    static let primaryDim    = Color(hex: "#516048").opacity(0.10)
    // Shadows  (blur values in HTML → SwiftUI radius ≈ blur/2)
    static let shadowS       = (color: Color(red: 90/255, green: 103/255, blue: 80/255).opacity(0.08), radius: CGFloat(7),  x: CGFloat(0), y: CGFloat(2))
    static let shadowHero    = (color: Color(red: 90/255, green: 103/255, blue: 80/255).opacity(0.12), radius: CGFloat(14), x: CGFloat(0), y: CGFloat(8))
    static let streakRadius: CGFloat = 999
    static let cardRadius: CGFloat = 18
    static let heroRadius: CGFloat = 24
    static let strokeWidth: CGFloat = 1
}

/// Drives the SetReminderSheet presentation from an insights urgent-flag prompt.
private struct ReminderPromptItem: Identifiable {
    let id = UUID()
    let name: String
    let date: Date
}

/// Pairs a procedure with the section to scroll to on open.
/// Including the anchor in `id` ensures sheet(item:) re-presents
/// even when the same procedure is shown with a different anchor.
private struct InsightsPresentation: Identifiable {
    let procedureId: String
    let procedureName: String
    let scrollAnchor: String?
    var id: String { procedureId + (scrollAnchor ?? "") }
}

struct PhotoJournalView: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore
    var addEntryTrigger: Binding<Bool> = .constant(false)
    var onBackButtonTapped: (() -> Void)? = nil

    @State private var vm = JournalViewModel()
    @State private var groupToDelete: (key: String, entries: [JournalEntry])?
    @State private var insightPresentation: InsightsPresentation? = nil
    @State private var showChat = false
    @State private var showReminderSet = false
    @State private var upcomingReminders: [TreatmentReminder] = []
    @State private var reminderPromptItem: ReminderPromptItem? = nil
    @State private var showPaywall = false
    @State private var isSubscribed = false

    private let userProfileService = UserProfileService(supabase: supabase)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection

                if vm.isLoading && vm.entries.isEmpty {
                    Spacer()
                    ProgressView().tint(J.accent)
                    Spacer()
                } else {
                    mainContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(J.pageBg.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { procedureName in
                ProcedureEntriesView(procedureName: procedureName, vm: vm)
            }
            .navigationDestination(for: AllEntriesRoute.self) { _ in
                ProcedureEntriesView(procedureName: nil, vm: vm)
            }
            .navigationDestination(for: UUID.self) { entryId in
                if let entry = vm.entries.first(where: { $0.id == entryId }) {
                    JournalEntryDetailView(
                        entry: entry,
                        onDelete: { await vm.deleteEntry(entry) }
                    )
                }
            }
            .alert("Couldn't Save Entry", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) {
                Button("OK", role: .cancel) { vm.error = nil }
            } message: {
                Text(vm.error ?? "")
            }
            .overlay(alignment: .bottom) {
                if vm.showConsentBanner {
                    PhotoConsentBannerView(
                        onGrant: { vm.grantConsent() },
                        onDeny:  { vm.denyConsent() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(duration: 0.35), value: vm.showConsentBanner)
                }
            }
        }
        .sheet(isPresented: $vm.showAddEntry, onDismiss: {
            vm.pendingProcedureName = nil
            upcomingReminders = TreatmentReminderStore.shared.activeUpcoming()
            // Open insights immediately for the procedure just journaled.
            // AllInsightsView shows a loading state while generation is in-flight.
            if isSubscribed, let entry = vm.entries.first {
                let count = vm.groupedByProcedure
                    .first { $0.entries.first?.procedureId == entry.procedureId }?
                    .entries.count ?? 0
                if count >= 2 {
                    insightPresentation = InsightsPresentation(
                        procedureId: entry.procedureId,
                        procedureName: entry.procedureName,
                        scrollAnchor: nil
                    )
                }
            }
        }) {
            AddJournalEntryView(vm: vm, prefilledProcedureName: vm.pendingProcedureName)
        }
        .task {
            await subscriptionStore.prepare()
            await vm.load()
            await refreshSubscriptionState()
            TreatmentReminderStore.shared.pruneExpired()
            upcomingReminders = TreatmentReminderStore.shared.activeUpcoming()
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
            Task {
                await refreshSubscriptionState()
            }
        }
        .onChange(of: addEntryTrigger.wrappedValue) { _, triggered in
            if triggered {
                vm.tapAddEntry()
                addEntryTrigger.wrappedValue = false
            }
        }
        .onChange(of: vm.entries.count) { oldCount, newCount in
            // Regenerate insights for every eligible procedure when a new entry is added.
            // Always regenerates (no nil guard) so insights reflect the latest entry.
            guard isSubscribed, newCount > oldCount else { return }
            Task {
                for group in vm.groupedByProcedure where group.entries.count >= 2 {
                    guard let procedureId = group.entries.first?.procedureId else { continue }
                    await vm.refreshInsights(for: procedureId, procedureName: group.key)
                }
            }
        }
        .alert(
            "Delete \"\(groupToDelete?.key ?? "")\"?",
            isPresented: Binding(get: { groupToDelete != nil }, set: { if !$0 { groupToDelete = nil } })
        ) {
            Button("Delete All Entries", role: .destructive) {
                guard let group = groupToDelete,
                      let procedureId = group.entries.first?.procedureId else { return }
                groupToDelete = nil
                Task { await vm.deleteProcedureGroup(procedureId: procedureId) }
            }
            Button("Cancel", role: .cancel) { groupToDelete = nil }
        } message: {
            let count = groupToDelete?.entries.count ?? 0
            Text("This will permanently delete all \(count) \(count == 1 ? "entry" : "entries") in this group.")
        }
        .sheet(item: $insightPresentation) { pres in
            AllInsightsView(vm: vm, procedureId: pres.procedureId, procedureName: pres.procedureName, scrollAnchor: pres.scrollAnchor)
        }
        .sheet(isPresented: $showChat) {
            ChatView()
        }
        .sheet(isPresented: $showPaywall) {
            QuotaExceededView(
                onDismiss: { showPaywall = false },
                onSubscribed: {
                    showPaywall = false
                    isSubscribed = true
                    vm.insightsEnabled = true
                    vm.loadCachedInsights()
                    vm.loadCachedWeeklySummaries()
                    Task {
                        await vm.loadRemoteWeeklySummaries()
                        for group in vm.groupedByProcedure where group.entries.count >= 2 {
                            guard let procedureId = group.entries.first?.procedureId,
                                  vm.insights[procedureId] == nil else { continue }
                            await vm.refreshInsights(for: procedureId, procedureName: group.key)
                        }
                    }
                }
            )
        }
        .alert("Reminder Set", isPresented: $showReminderSet) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We'll remind you to check in on your recovery tomorrow morning.")
        }
        .sheet(item: $reminderPromptItem, onDismiss: {
            upcomingReminders = TreatmentReminderStore.shared.activeUpcoming()
        }) { item in
            SetReminderSheet(procedureName: item.name, procedureDate: item.date)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack {
            // Centered title
            Text("My Journal")
                .font(.custom("Manrope", size: 24))
                .fontWeight(.bold)
                .foregroundColor(J.textHi)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                // Back button — chevron in circle (matches HTML .back-btn)
                Button { onBackButtonTapped?() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(J.textHi)
                        .frame(width: 36, height: 36)
                        .background(J.cardWhite)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(J.border, lineWidth: 1))
                        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
                }

                Spacer()

                // Empty spacer to balance the back button and keep title centered
                Color.clear.frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 52)
        .padding(.bottom, 14)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                JournalStreakStrip(
                    streak: vm.streak,
                    dayNumber: vm.heroData?.dayNumber ?? 0,
                    procedureName: vm.primaryProcedureName
                )
                .padding(.horizontal, 18)

                JournalTodayCard(
                    latestEntry: vm.latestEntry,
                    procedureName: vm.primaryProcedureName,
                    onLogToday: { vm.tapAddEntry(for: vm.primaryProcedureName) }
                )
                .padding(.horizontal, 18)
                .padding(.top, 2)

                HStack(alignment: .top, spacing: 12) {
                    JournalPainTrendCard(painSeries: vm.primaryPainSeries)
                    JournalTodaySignalsCard(
                        pain: vm.latestPainLevel,
                        swelling: vm.latestSwellingLevel,
                        bruising: vm.latestBruisingLevel
                    )
                }
                .padding(.horizontal, 18)

                if let alert = vm.journalAlert {
                    JournalAlertCard(alert: alert)
                        .padding(.horizontal, 18)
                        .padding(.top, 2)
                }

                JournalWeeklyReportCard(
                    preview: resolvedWeeklyPreview,
                    onOpenReport: {
                        guard isSubscribed else {
                            showPaywall = true
                            return
                        }
                        guard let procedureId = vm.primaryProcedureId,
                              let procedureName = vm.primaryProcedureName else { return }
                        insightPresentation = InsightsPresentation(
                            procedureId: procedureId,
                            procedureName: procedureName,
                            scrollAnchor: nil
                        )
                    }
                )
                .padding(.horizontal, 18)
                .padding(.top, 10)

                if vm.entries.isEmpty {
                    emptyEntriesSection
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                } else {
                    recentEntriesSection
                        .padding(.top, 12)
                }

                JournalCalendarStrip(
                    weekDates: vm.currentWeekDates,
                    entryDates: Set(vm.entries.map(\.entryDate)),
                    onDateTap: { date in
                        let key = isoDate(date)
                        // Past/today date with no entry → open add entry sheet
                        if !vm.entries.contains(where: { $0.entryDate == key }) {
                            vm.tapAddEntry()
                        }
                    }
                )
                .padding(.horizontal, 18)
                .padding(.top, 4)

                JournalPhotoReelSection(entries: vm.photoReelEntries())
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                Color.clear.frame(height: 124)
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Empty Entries Section

    private var emptyEntriesSection: some View {
        let isNewUser = !vm.hasEverLoggedEntry
        return VStack(spacing: 16) {
            Text("✦")
                .font(.system(size: 24))
                .foregroundColor(J.accent.opacity(0.45))

            VStack(spacing: 6) {
                Text(isNewUser ? "Your story starts here." : "Welcome back.")
                    .font(.custom("Manrope", size: 22))
                    .fontWeight(.bold)
                    .foregroundColor(J.textHi)
                    .multilineTextAlignment(.center)

                Text(
                    isNewUser
                        ? "Log your first entry to begin tracking your recovery journey."
                        : "Ready to continue your story? Log an entry to keep your journey going."
                )
                .font(.custom("PlusJakartaSans-Regular", size: 13))
                .foregroundColor(J.textLo)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            }

            // Primary CTA
            Button { vm.tapAddEntry() } label: {
                Text(isNewUser ? "Begin Your Journey" : "Add Entry")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(J.primary)
                    .cornerRadius(100)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .background(J.cardWhite)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(J.border, lineWidth: 1))
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
    }

    // MARK: - Recent Entries Section

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Entries")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                        .kerning(2.1)
                        .foregroundColor(J.textLo)
                        .textCase(.uppercase)

                    Text("Latest logs")
                        .font(.custom("Manrope", size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(J.textHi)
                }

                Spacer()

                NavigationLink(value: AllEntriesRoute()) {
                    Text("See all")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                        .foregroundColor(J.primary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 12) {
                ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
                    NavigationLink(value: entry.id) {
                        CompactEntryRow(entry: entry, isEmphasized: index == 0)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { deleteGroupButton(for: entry) }
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.72))
        .cornerRadius(28)
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(J.border, lineWidth: J.strokeWidth))
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
        .padding(.horizontal, 18)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func deleteGroupButton(for entry: JournalEntry) -> some View {
        Button(role: .destructive) {
            if let group = vm.groupedByProcedure.first(where: { $0.key == entry.procedureName }) {
                groupToDelete = group
            }
        } label: {
            Label("Delete Group", systemImage: "trash")
        }
    }

    private var sortedEntries: [JournalEntry] {
        vm.recentEntries()
    }

    private var resolvedWeeklyPreview: JournalWeeklyReportPreview {
        if !isSubscribed {
            return JournalWeeklyReportPreview(
                weekNumber: 1,
                title: "Premium feature: Weekly AI reports.",
                subtitle: "Subscribe to unlock automated weekly reports, AI insights, and personalized recovery guidance.",
                statusLabel: "Premium feature",
                progress: 0,
                actionTitle: "Unlock Premium",
                summary: nil
            )
        }

        if let preview = vm.weeklyReportPreview {
            return preview
        }

        let hasEntries = !vm.entries.isEmpty
        return JournalWeeklyReportPreview(
            weekNumber: 1,
            title: hasEntries ? "Week 1 is almost ready." : "Week 1 is getting started.",
            subtitle: hasEntries
                ? "Add one more detailed log and your weekly report will auto-fill with trends and insights."
                : "Keep logging daily and your weekly report will auto-fill with trends and insights.",
            statusLabel: hasEntries ? "Building" : "Starting",
            progress: hasEntries ? max(68, vm.weeklyReportProgress) : 18,
            actionTitle: hasEntries ? "See preview" : "Keep logging",
            summary: nil
        )
    }

    private func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Subscription

    private func refreshSubscriptionState() async {
        do {
            let profile = try await userProfileService.getUserProfile()
            let subscribed = subscriptionStore.hasActiveSubscription
                || SubscriptionAccessEvaluator.hasBackendPremiumAccess(profile)
            isSubscribed = subscribed
            vm.insightsEnabled = subscribed

            if !subscribed {
                vm.clearAIOutputs()
                return
            }

            // Load the cache only now that insightsEnabled is set, so free users never
            // briefly see stale cached insights from a lapsed subscription.
            vm.loadCachedInsights()
            vm.loadCachedWeeklySummaries()
            await vm.loadRemoteWeeklySummaries()

            // Generate insights for every eligible procedure that has no cached result.
            // Handles entries that pre-date the insights feature, a cleared cache, or
            // procedures other than the one with the most entries.
            guard subscribed else { return }
            for group in vm.groupedByProcedure where group.entries.count >= 2 {
                guard let procedureId = group.entries.first?.procedureId,
                      vm.insights[procedureId] == nil else { continue }
                await vm.refreshInsights(for: procedureId, procedureName: group.key)
            }
        } catch {
            print("Journal subscription check failed: \(error)")
            isSubscribed = false
            vm.insightsEnabled = false
            vm.clearAIOutputs()
        }
    }

    /// Looks up the earliest journal entry date for a procedure, falling back to today.
    /// Used to anchor surgical follow-up milestone dates in SetReminderSheet.
    private func earliestEntryDate(for procedureName: String) -> Date {
        let pid = procedureName.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return vm.entries
            .filter { $0.procedureId == pid }
            .min(by: { $0.entryDateAsDate < $1.entryDateAsDate })?
            .entryDateAsDate ?? Date()
    }

    private func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Recovery Check-in"
            content.body = "How are you feeling today? Log your recovery progress with Rena."
            content.sound = .default
            let cal = Calendar.current
            if let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) {
                var components = cal.dateComponents([.year, .month, .day], from: tomorrow)
                components.hour = 9
                components.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "recovery-reminder-\(UUID())",
                    content: content,
                    trigger: trigger
                )
                center.add(request, withCompletionHandler: nil)
            }
        }
    }
}

// MARK: - Recovery Hero Card

private struct JournalHeroCard: View {
    let heroData: (procedureName: String, dayNumber: Int, progress: Double)?
    let streak: Int
    let isNewUser: Bool
    let recoveryScore: Int?
    let hasLoggedToday: Bool
    let onLogToday: () -> Void

    var body: some View {
        ZStack {
            // 1. Background gradient: 130deg, #6B3346 → #8E4C5C → #B76E79
            LinearGradient(
                stops: [
                    .init(color: J.gradA,   location: 0.00),
                    .init(color: J.gradMid, location: 0.52),
                    .init(color: J.gradB,   location: 1.00)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 2. Decorative circle rings (bottom-right, partially clipped)
            GeometryReader { geo in
                // Outer ring: 170×170, center at (width-45, height-35)
                Circle()
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
                    .frame(width: 170, height: 170)
                    .position(x: geo.size.width - 45, y: geo.size.height - 35)

                // Inner ring: 110×110, center at (width-65, height-45)
                Circle()
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
                    .frame(width: 110, height: 110)
                    .position(x: geo.size.width - 65, y: geo.size.height - 45)
            }

            // 3. Card content
            HStack(alignment: .top, spacing: 0) {
                // Left column: eyebrow, day number, label, progress
                VStack(alignment: .leading, spacing: 0) {
                    Text("RECOVERY JOURNEY")
                        .font(.custom("Outfit-Regular", size: 9))
                        .kerning(3)
                        .foregroundColor(.white.opacity(0.55))

                    Spacer().frame(height: 3)

                    Text(heroData != nil ? "\(heroData!.dayNumber)" : "0")
                        .font(.system(size: 40, weight: .light, design: .serif))
                        .foregroundColor(heroData != nil ? .white : .white.opacity(0.3))

                    Text(
                        heroData != nil
                            ? "days of recovery"
                            : (isNewUser ? "your journey begins today" : "welcome back")
                    )
                    .font(.custom("Outfit-Light", size: 10))
                    .foregroundColor(heroData != nil ? .white.opacity(0.65) : .white.opacity(0.35))
                    .lineLimit(1)

                    Spacer().frame(height: 10)

                    progressBar(progress: heroData?.progress ?? 0)

                    Spacer().frame(height: 12)

                    Button(action: onLogToday) {
                        HStack(spacing: 8) {
                            Image(systemName: hasLoggedToday ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text(hasLoggedToday ? "Logged today" : "Log today")
                                .font(.custom("Outfit-SemiBold", size: 12))
                        }
                        .foregroundColor(J.textHi)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.88))
                        .clipShape(Capsule())
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    if let recoveryScore {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Recovery Score")
                                .font(.custom("Outfit-Regular", size: 9))
                                .foregroundColor(.white.opacity(0.6))
                            Text("\(recoveryScore)/100")
                                .font(.system(size: 22, weight: .regular, design: .serif))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    if streak > 0 {
                        Text("🔥 \(streak)-day streak")
                            .font(.custom("Outfit-SemiBold", size: 9))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.16))
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(
            color: J.shadowHero.color,
            radius: J.shadowHero.radius,
            x: J.shadowHero.x,
            y: J.shadowHero.y
        )
    }

    private func progressBar(progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 100)
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 3)
                    // Fill: white opacity gradient (matches HTML)
                    RoundedRectangle(cornerRadius: 100)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.6), Color.white.opacity(0.95)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * 0.8 * max(progress, 0), height: 3)
                        .animation(.easeOut(duration: 0.8), value: progress)
                }
            }
            .frame(width: nil, height: 3)
            // Constrain to ~80% width like the HTML
            .frame(maxWidth: .infinity)
            .padding(.trailing, 40)

            Text(
                heroData != nil
                    ? "\(Int(progress * 100))% of 28-day plan"
                    : "start logging to track progress"
            )
            .font(.custom("Outfit-Regular", size: 9))
            .foregroundColor(.white.opacity(0.48))
        }
    }
}

private struct SmartRecoveryAlertsSection: View {
    let alerts: [SmartRecoveryAlert]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(J.gradB)
                Text("Smart Recovery Alerts")
                    .font(.custom("Outfit-SemiBold", size: 14))
                    .foregroundColor(J.textHi)
            }

            ForEach(alerts) { alert in
                VStack(alignment: .leading, spacing: 6) {
                    Text(alert.title)
                        .font(.custom("Outfit-SemiBold", size: 13))
                        .foregroundColor(J.textHi)
                    Text(alert.message)
                        .font(.custom("Outfit-Regular", size: 12))
                        .foregroundColor(J.textHi.opacity(0.72))
                        .lineSpacing(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(alert.severity == .warning ? J.concernTint : J.positiveTint)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(alert.severity == .warning ? J.gradB.opacity(0.16) : J.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

private struct HealingProgressSection: View {
    let score: RecoveryScoreSnapshot?
    let painSeries: [Int]
    let photoTimeline: [JournalEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Healing Progress")
                    .font(.custom("Outfit-SemiBold", size: 14))
                    .foregroundColor(J.textHi)
                Spacer()
                if let score {
                    Text("\(score.consistencyRate)% consistent")
                        .font(.custom("Outfit-Regular", size: 11))
                        .foregroundColor(J.textLo)
                }
            }

            if !painSeries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pain trend")
                        .font(.custom("Outfit-SemiBold", size: 12))
                        .foregroundColor(J.textHi)
                    HStack(spacing: 8) {
                        Text(painSeries.map(String.init).joined(separator: " → "))
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .foregroundColor(J.primary)
                        Spacer()
                    }
                }
            }

            if !photoTimeline.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Photo timeline")
                        .font(.custom("Outfit-SemiBold", size: 12))
                        .foregroundColor(J.textHi)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(photoTimeline) { entry in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Day \(entry.dayNumber)")
                                        .font(.custom("Outfit-SemiBold", size: 11))
                                        .foregroundColor(J.primary)
                                    Text(entry.entryDate)
                                        .font(.custom("Outfit-Regular", size: 10))
                                        .foregroundColor(J.textLo)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(J.cardWhite)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(J.border, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(J.cardWhite)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(J.border, lineWidth: 1))
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
    }
}

// MARK: - Rena Insights Section

private struct JournalInsightsSection: View {
    let insights: RecoveryInsights?
    let isGenerating: Bool
    let isEmpty: Bool
    var isSubscribed: Bool = true
    /// Active upcoming reminders — used to detect urgent-flag + no-reminder state.
    var upcomingReminders: [TreatmentReminder] = []
    /// Called with the scroll anchor for the section to jump to ("nextSteps", "flags",
    /// "encouragements", or nil for the top). Replaces the old onSeeAll/onViewTrends pair.
    var onShowInsights: ((String?) -> Void)? = nil
    var onUnlock: (() -> Void)? = nil
    var onTalkToRena: (() -> Void)? = nil
    var onSetReminder: (() -> Void)? = nil
    /// Fired when the user taps "Schedule now" on an urgent-flag/no-reminder prompt card.
    /// Passes the procedure name; caller resolves the procedure date.
    var onScheduleFromInsights: ((String) -> Void)? = nil

    private var showUrgentFollowUpPrompt: Bool {
        guard let insights else { return false }
        return JournalViewModel.urgentFlagNeedsReminder(
            insights: insights,
            upcomingReminders: upcomingReminders
        )
    }

    private var insightCardCount: Int {
        guard let insights else { return 0 }
        var count = 1
        count += min(2, insights.flags.count)
        if !insights.encouragements.isEmpty { count += 1 }
        if insights.nextSteps != nil { count += 1 }
        if showUrgentFollowUpPrompt { count += 1 }
        return count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            // Section header
            HStack(spacing: 7) {
                // Rena AI logo mark: 22×22 rounded square, gradient, concentric circles
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        LinearGradient(
                            colors: [J.gradA, J.gradMid, J.gradB],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                    .overlay(concentricCirclesIcon)

                Text("Rena Insights")
                    .font(.custom("Outfit-SemiBold", size: 13))
                    .foregroundColor(J.textHi)

                if !isEmpty, insights != nil {
                    Text("\(insightCardCount)")
                        .font(.custom("Outfit-Bold", size: 9.5))
                        .foregroundColor(J.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(J.primaryDim)
                        .clipShape(Capsule())
                }

                Spacer()

                if isSubscribed, insights != nil {
                    Button { onShowInsights?(nil) } label: {
                        Text("See all")
                            .font(.custom("Outfit-Regular", size: 11))
                            .foregroundColor(J.accent)
                            .padding(.vertical, 8)
                            .padding(.leading, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)

            // Horizontal card carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    if isEmpty {
                        InsightCard(type: .placeholder, message: "Premium feature. Subscribe to unlock AI-powered recovery insights from your journal.")
                    } else if !isSubscribed {
                        InsightCard(
                            type: .locked,
                            message: "Premium feature. Subscribe to unlock AI-powered recovery insights personalized to your healing journey.",
                            onCTA: onUnlock
                        )
                    } else if isGenerating && insights == nil {
                        InsightCard(type: .generating, message: "Analyzing your recovery journey…")
                    } else if let insights {
                        InsightCard(type: .progress, message: insights.summary,
                                    onCTA: { onShowInsights?(nil) })
                        ForEach(Array(insights.flags.prefix(2).enumerated()), id: \.offset) { _, flag in
                            InsightCard(
                                type: flag.severity == .urgent ? .concern : .reminder,
                                message: flag.message,
                                onCTA: flag.severity == .urgent ? onTalkToRena : onSetReminder
                            )
                        }
                        // Urgent flag + no reminder scheduled → prompt to set one
                        if showUrgentFollowUpPrompt {
                            InsightCard(
                                type: .urgentFollowUp,
                                message: "A concern was flagged but no follow-up reminder is scheduled for \(insights.procedureName). Set one to stay protected.",
                                onCTA: { onScheduleFromInsights?(insights.procedureName) }
                            )
                        }
                        if let encouragement = insights.encouragements.first {
                            InsightCard(type: .progress, message: encouragement,
                                        onCTA: { onShowInsights?("encouragements") })
                        }
                        if let nextSteps = insights.nextSteps {
                            InsightCard(type: .nextSteps, message: nextSteps,
                                        onCTA: { onShowInsights?("nextSteps") })
                        }
                    } else {
                        InsightCard(type: .placeholder, message: "Premium feature. Keep logging if you want, then subscribe to unlock AI-powered recovery insights.")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 2)
            }

            // Scroll position dots
            if insightCardCount > 1 {
                HStack(spacing: 5) {
                    Capsule()
                        .fill(J.primary)
                        .frame(width: 14, height: 5)
                    ForEach(0..<(insightCardCount - 1), id: \.self) { _ in
                        Circle()
                            .fill(J.border)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var concentricCirclesIcon: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 0.8)
                .frame(width: 11, height: 11)
            Circle()
                .stroke(Color.white.opacity(0.8), lineWidth: 0.8)
                .frame(width: 7.2, height: 7.2)
            Circle()
                .stroke(Color.white, lineWidth: 0.8)
                .frame(width: 3.4, height: 3.4)
            Circle()
                .fill(Color.white)
                .frame(width: 1.5, height: 1.5)
        }
    }
}

// MARK: - Insight Card

private enum InsightCardType {
    case concern, reminder, progress, placeholder, generating, nextSteps, locked
    /// Urgent flag exists but no follow-up reminder is scheduled — prompt user to set one.
    case urgentFollowUp

    var accentColor: Color {
        switch self {
        case .concern:              return J.gradB     // Rose Gold #B76E79
        case .reminder:             return J.accent    // Dusty Rose #C4929A
        case .progress:             return J.primary   // Mauve Berry #8E4C5C
        case .nextSteps:            return J.primary
        case .locked:               return J.gradB
        case .urgentFollowUp:       return J.gradB
        case .placeholder, .generating: return J.accent
        }
    }
    var tintBackground: Color {
        switch self {
        case .concern:              return J.concernTint   // #FEF0F2
        case .reminder:             return J.reminderTint  // #FDF5F6
        case .progress:             return J.positiveTint  // #F8EDF0
        case .nextSteps:            return J.positiveTint
        case .locked:               return J.concernTint
        case .urgentFollowUp:       return J.concernTint
        case .placeholder, .generating: return Color(hex: "#FDF5F6")
        }
    }
    var borderColor: Color {
        switch self {
        case .concern:              return J.gradB.opacity(0.22)
        case .reminder:             return J.accent.opacity(0.22)
        case .progress:             return J.primary.opacity(0.18)
        case .nextSteps:            return J.primary.opacity(0.18)
        case .locked:               return J.gradB.opacity(0.22)
        case .urgentFollowUp:       return J.gradB.opacity(0.35)
        case .placeholder, .generating: return J.accent.opacity(0.18)
        }
    }
    var icon: String {
        switch self {
        case .concern:         return "exclamationmark.triangle.fill"
        case .reminder:        return "bell.fill"
        case .progress:        return "star.fill"
        case .nextSteps:       return "list.bullet"
        case .locked:          return "lock.fill"
        case .urgentFollowUp:  return "alarm.fill"
        case .placeholder, .generating: return "sparkles"
        }
    }
    var typeLabel: String {
        switch self {
        case .concern:         return "CONCERN"
        case .reminder:        return "REMINDER"
        case .progress:        return "PROGRESS"
        case .nextSteps:       return "NEXT STEPS"
        case .locked:          return "PREMIUM"
        case .urgentFollowUp:  return "ACTION NEEDED"
        case .placeholder:     return "INSIGHTS"
        case .generating:      return "ANALYZING"
        }
    }
    var ctaLabel: String {
        switch self {
        case .concern:         return "Talk to Rena"
        case .reminder:        return "Set reminder"
        case .progress:        return "View trends"
        case .nextSteps:       return "See all"
        case .locked:          return "Unlock Insights"
        case .urgentFollowUp:  return "Schedule now"
        case .placeholder, .generating: return ""
        }
    }
}

private struct InsightCard: View {
    let type: InsightCardType
    let message: String
    var onCTA: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar — full card height via clipShape
            Rectangle()
                .fill(type.accentColor)
                .frame(width: 3.5)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Type header
                HStack(spacing: 6) {
                    // Icon in tinted square
                    RoundedRectangle(cornerRadius: 6)
                        .fill(type.accentColor.opacity(0.14))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: type.icon)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(type.accentColor)
                        )

                    Text(type.typeLabel)
                        .font(.custom("Outfit-Bold", size: 9))
                        .kerning(1.5)
                        .foregroundColor(type.accentColor)
                }

                // Body text
                Text(message)
                    .font(.custom("Outfit-Regular", size: 11.5))
                    .foregroundColor(J.textHi)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // CTA (hidden for placeholder/generating)
                if !type.ctaLabel.isEmpty {
                    Button(action: { onCTA?() }) {
                        HStack(spacing: 4) {
                            Text(type.ctaLabel)
                                .font(.custom("Outfit-SemiBold", size: 10.5))
                                .foregroundColor(type.accentColor)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(type.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(type.tintBackground)
        }
        .frame(width: 218)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(type.borderColor, lineWidth: 1)
        )
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
    }
}

// MARK: - Calendar Strip

private struct JournalCalendarStrip: View {
    let weekDates: [Date]
    let entryDates: Set<String>
    var onDateTap: ((Date) -> Void)? = nil

    private static let dayNameFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()
    private static let entryKeyFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery calendar")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                        .kerning(2.0)
                        .foregroundColor(J.textLo)
                        .textCase(.uppercase)
                    Text("Your check-in rhythm")
                        .font(.custom("Manrope", size: 24))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#314030"))
                }
                Spacer()

                Text("This week")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .foregroundColor(J.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.82))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(J.border.opacity(0.7), lineWidth: J.strokeWidth))
            }

            HStack(spacing: 8) {
                ForEach(weekDates, id: \.self) { date in
                    dayCell(date: date)
                }
            }
        }
        .padding(18)
        .background(J.card)
        .cornerRadius(28)
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(J.border, lineWidth: J.strokeWidth))
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
    }

    private func dayCell(date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()
        let dateKey = Self.entryKeyFormatter.string(from: date)
        let hasEntry = entryDates.contains(dateKey)
        let dayNum = calendar.component(.day, from: date)
        let dayName = String(Self.dayNameFormatter.string(from: date).prefix(3))
        let isTappable = !isFuture

        return VStack(alignment: .center, spacing: 8) {
            Text(dayName)
                .font(.custom("PlusJakartaSans-Regular", size: 10))
                .foregroundColor(isToday && !hasEntry ? Color(hex: "#A85555") : (hasEntry ? J.primary : (isFuture ? J.textLo.opacity(0.4) : J.textLo)))
                .fontWeight((isToday || hasEntry) ? .semibold : .regular)

            VStack(spacing: 8) {
                Text("\(dayNum)")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                    .foregroundColor(
                        isToday && !hasEntry ? J.textHi
                        : isFuture ? J.textLo.opacity(0.35)
                        : hasEntry ? J.primary
                        : J.textLo
                    )

                Circle()
                    .fill(hasEntry ? J.primary : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(cellBackground(isToday: isToday, hasEntry: hasEntry, isFuture: isFuture))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isTappable else { return }
            onDateTap?(date)
        }
    }

    private func cellBackground(isToday: Bool, hasEntry: Bool, isFuture: Bool) -> Color {
        if isToday && !hasEntry { return J.roseSoft }
        if hasEntry { return Color.white.opacity(0.95) }
        if isFuture { return Color.white.opacity(0.56) }
        return Color.white.opacity(0.8)
    }
}

// MARK: - Compact Entry Row

private struct CompactEntryRow: View {
    let entry: JournalEntry
    var isEmphasized: Bool = false

    private static let entryKeyFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    private var notePreview: String {
        let trimmed = entry.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Your latest recovery notes will appear here." : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.procedureName)
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                        .foregroundColor(J.textHi)
                        .lineLimit(1)

                    Text("\(entry.dayLabel) • \(Self.entryKeyFormatter.string(from: entry.entryDateAsDate))")
                        .font(.custom("PlusJakartaSans-Regular", size: 11))
                        .foregroundColor(J.textLo)
                }

                Spacer()

                if let badgeText {
                    Text(badgeText)
                        .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                        .foregroundColor(Color(hex: "#314030"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(badgeBackground)
                        .clipShape(Capsule())
                }
            }

            Text(notePreview)
                .font(.custom("PlusJakartaSans-Regular", size: 13))
                .foregroundColor(J.textLo)
                .lineSpacing(4)
                .lineLimit(3)
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(J.border.opacity(0.75), lineWidth: J.strokeWidth))
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
    }

    private var badgeText: String? {
        if Calendar.current.isDateInToday(entry.entryDateAsDate) {
            return "today"
        }
        if entry.photoUrl != nil || entry.photoPath != nil {
            return "photo saved"
        }
        return nil
    }

    private var badgeBackground: Color {
        if badgeText == "photo saved" {
            return J.roseSoft
        }
        return Color.white.opacity(0.92)
    }

    private var cardBackground: Color {
        if entry.photoUrl != nil || entry.photoPath != nil {
            return Color(hex: "#E1E7DA")
        }
        return isEmphasized ? J.card : Color.white
    }
}

// MARK: - Upcoming Reminders Section

private struct UpcomingRemindersSection: View {
    let reminders: [TreatmentReminder]
    let onDelete: (UUID) -> Void

    var body: some View {
        if !reminders.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(J.primary)
                    Text("Upcoming Reminders")
                        .font(.custom("Outfit-SemiBold", size: 13))
                        .foregroundColor(J.textHi)
                    Text("\(reminders.count)")
                        .font(.custom("Outfit-Bold", size: 9.5))
                        .foregroundColor(J.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(J.primaryDim)
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.horizontal, 18)

                // Reminder rows
                VStack(spacing: 6) {
                    ForEach(reminders) { reminder in
                        ReminderRow(reminder: reminder, onDelete: { onDelete(reminder.id) })
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }
}

private struct ReminderRow: View {
    let reminder: TreatmentReminder
    let onDelete: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
    }()

    private var kindIcon: String {
        switch reminder.kind {
        case .retreatment: return "clock.arrow.circlepath"
        case .followUp:    return "calendar.badge.checkmark"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Kind icon
            Image(systemName: kindIcon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(J.primary)
                .frame(width: 28, height: 28)
                .background(J.primaryDim)
                .clipShape(Circle())

            // Label + procedure
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.label)
                    .font(.custom("Outfit-SemiBold", size: 12))
                    .foregroundColor(J.textHi)
                    .lineLimit(1)
                Text(reminder.procedureName)
                    .font(.custom("Outfit-Regular", size: 11))
                    .foregroundColor(J.textLo)
                    .lineLimit(1)
            }

            Spacer()

            // Date
            Text(Self.dateFormatter.string(from: reminder.reminderDate))
                .font(.custom("Outfit-Regular", size: 11))
                .foregroundColor(J.accent)

            // Cancel
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(J.textLo)
                    .frame(width: 20, height: 20)
                    .background(J.border)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(J.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(J.border, lineWidth: 1))
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
    }
}

#Preview {
    PhotoJournalView()
}
