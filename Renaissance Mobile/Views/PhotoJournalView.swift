//
//  PhotoJournalView.swift
//  Renaissance Mobile
//

import SwiftUI
import UserNotifications
import StripePaymentSheet
import Supabase

// MARK: - Design tokens — sourced directly from rena-journal-ai-insights.html

private enum J {
    static let pageBg        = Color(hex: "#FFF8F6")
    static let primary       = Color(hex: "#8E4C5C")   // Mauve Berry – positive / progress
    static let gradA         = Color(hex: "#6B3346")   // Hero gradient dark end
    static let gradMid       = Color(hex: "#8E4C5C")   // Hero gradient mid stop (52%)
    static let gradB         = Color(hex: "#B76E79")   // Rose Gold – concern / flag
    static let accent        = Color(hex: "#C4929A")   // Dusty Rose – reminder / calendar active
    static let textHi        = Color(hex: "#3D2B2E")
    static let textLo        = Color(hex: "#B8A9AB")
    static let card          = Color(hex: "#F8EDF0")
    static let cardWhite     = Color.white
    static let border        = Color(hex: "#C4929A").opacity(0.18)
    // AI card tints
    static let concernTint   = Color(hex: "#FEF0F2")
    static let reminderTint  = Color(hex: "#FDF5F6")
    static let positiveTint  = Color(hex: "#F8EDF0")
    // Dimmed primary (badges, arrow buttons)
    static let primaryDim    = Color(hex: "#8E4C5C").opacity(0.10)
    // Shadows  (blur values in HTML → SwiftUI radius ≈ blur/2)
    static let shadowS       = (color: Color(hex: "#8E4C5C").opacity(0.07), radius: CGFloat(7),  x: CGFloat(0), y: CGFloat(2))
    static let shadowHero    = (color: Color(hex: "#6B3346").opacity(0.30), radius: CGFloat(14), x: CGFloat(0), y: CGFloat(8))
    static let streakRadius: CGFloat = 999
    static let cardRadius: CGFloat = 18
    static let heroRadius: CGFloat = 24
    static let strokeWidth: CGFloat = 1
}

private struct AllEntriesRoute: Hashable {}

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
    var addEntryTrigger: Binding<Bool> = .constant(false)
    var onBackButtonTapped: (() -> Void)? = nil

    @State private var vm = JournalViewModel()
    @State private var groupToDelete: (key: String, entries: [JournalEntry])?
    @State private var insightPresentation: InsightsPresentation? = nil
    @State private var showChat = false
    @State private var showReminderSet = false
    @State private var upcomingReminders: [TreatmentReminder] = []
    @State private var reminderPromptItem: ReminderPromptItem? = nil
    @State private var subscriptionViewModel = SubscriptionViewModel()
    @State private var onboardingPaymentViewModel = OnboardingPaymentViewModel()
    @State private var showPaywall = false
    @State private var isSubscribed = false
    @State private var paymentErrorMessage = ""
    @State private var showPaymentError = false

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
            await vm.load()
            await checkSubscription()
            TreatmentReminderStore.shared.pruneExpired()
            upcomingReminders = TreatmentReminderStore.shared.activeUpcoming()
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
                reason: "Subscribe to unlock AI-powered recovery insights personalized to your healing journey.",
                silverPrice: onboardingPaymentViewModel.silverPriceInfo?.displayPrice ?? "...",
                goldPrice: onboardingPaymentViewModel.goldPriceInfo?.displayPrice ?? "...",
                annualPrice: onboardingPaymentViewModel.annualPriceInfo?.displayPrice ?? "...",
                onUpgrade: { tier in await handleUpgrade(tier: tier) },
                onDismiss: { showPaywall = false }
            )
            .task {
                if onboardingPaymentViewModel.silverPriceInfo == nil {
                    await onboardingPaymentViewModel.fetchPrices()
                }
            }
        }
        .alert("Payment Error", isPresented: $showPaymentError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(paymentErrorMessage)
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
                .font(.system(size: 22, weight: .regular, design: .serif))
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

                if vm.entries.isEmpty {
                    emptyEntriesSection
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                } else {
                    recentEntriesSection
                        .padding(.top, 10)
                }

                if let preview = vm.weeklyReportPreview {
                    JournalWeeklyReportCard(
                        preview: preview,
                        onOpenReport: {
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

                if !vm.photoReelEntries().isEmpty {
                    JournalPhotoReelSection(entries: vm.photoReelEntries())
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                }

                Color.clear.frame(height: 40)
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
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundColor(J.textHi)
                    .multilineTextAlignment(.center)

                Text(
                    isNewUser
                        ? "Log your first entry to begin tracking your recovery journey."
                        : "Ready to continue your story? Log an entry to keep your journey going."
                )
                .font(.custom("Outfit-Light", size: 13))
                .foregroundColor(J.textLo)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            }

            // Primary CTA
            Button { vm.tapAddEntry() } label: {
                Text(isNewUser ? "Begin Your Journey" : "Add Entry")
                    .font(.custom("Outfit-SemiBold", size: 14))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(J.primary)
                    .cornerRadius(100)
            }

            // Secondary CTA
            Button { } label: {
                Text(isNewUser ? "Explore sample insights" : "Learn how it works")
                    .font(.custom("Outfit-Regular", size: 13))
                    .foregroundColor(J.accent)
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
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Recent Entries")
                    .font(.custom("Outfit-Regular", size: 10))
                    .kerning(2.1)
                    .foregroundColor(J.textHi)
                    .textCase(.uppercase)
                Spacer()
                NavigationLink(value: AllEntriesRoute()) {
                    Text("See all")
                        .font(.custom("Outfit-SemiBold", size: 11))
                        .foregroundColor(J.accent)
                }
            }
            .padding(.horizontal, 18)

            VStack(spacing: 7) {
                ForEach(sortedEntries) { entry in
                    NavigationLink(value: entry.id) {
                        CompactEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { deleteGroupButton(for: entry) }
                }
            }
            .padding(.horizontal, 18)
        }
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

    private func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Subscription

    private func checkSubscription() async {
        do {
            guard let userId = supabase.auth.currentUser?.id.uuidString else { return }
            let profile: UserProfile = try await supabase.database
                .from("user_profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            let subscribed = profile.billingPlan == .silver || profile.billingPlan == .gold
            isSubscribed = subscribed
            vm.insightsEnabled = subscribed

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
        }
    }

    private func handleUpgrade(tier: SubscriptionTier) async {
        let priceId: String
        switch tier {
        case .silver:  priceId = AppConfig.stripeSilverPriceId
        case .gold:    priceId = AppConfig.stripeGoldPriceId
        case .annual:  priceId = AppConfig.stripeAnnualPriceId
        }

        guard !priceId.contains("REPLACE_WITH_YOUR") else {
            paymentErrorMessage = "Subscription plan not configured."
            showPaymentError = true
            return
        }

        guard let subscriptionResult = await subscriptionViewModel.createSubscription(
            priceId: priceId,
            tier: tier
        ) else {
            paymentErrorMessage = subscriptionViewModel.errorMessage ?? "Failed to create subscription"
            showPaymentError = true
            return
        }

        let clientSecret = subscriptionResult.clientSecret
        let subscriptionId = subscriptionResult.subscriptionId

        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Renaissance"
        configuration.allowsDelayedPaymentMethods = true
        configuration.returnURL = "renaissance://payment-complete"

        var appearance = PaymentSheet.Appearance()
        appearance.colors.primary = UIColor(red: 208/255, green: 187/255, blue: 149/255, alpha: 1.0)
        appearance.colors.background = UIColor(red: 247/255, green: 247/255, blue: 246/255, alpha: 1.0)
        appearance.colors.componentBackground = UIColor.white
        appearance.colors.componentBorder = UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1.0)
        appearance.colors.componentDivider = UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1.0)
        appearance.colors.text = UIColor(red: 51/255, green: 51/255, blue: 51/255, alpha: 1.0)
        appearance.colors.textSecondary = UIColor(red: 130/255, green: 130/255, blue: 130/255, alpha: 1.0)
        appearance.cornerRadius = 16
        configuration.appearance = appearance

        configuration.billingDetailsCollectionConfiguration.name = .always
        configuration.billingDetailsCollectionConfiguration.email = .always
        configuration.billingDetailsCollectionConfiguration.phone = .always
        configuration.billingDetailsCollectionConfiguration.address = .full
        configuration.applePay = PaymentSheet.ApplePayConfiguration(
            merchantId: AppConfig.appleMerchantId,
            merchantCountryCode: "US"
        )

        let paymentSheet = PaymentSheet(
            paymentIntentClientSecret: clientSecret,
            configuration: configuration
        )

        guard let topViewController = UIApplication.shared.topViewController else {
            paymentErrorMessage = "Unable to present payment screen"
            showPaymentError = true
            return
        }

        let result = await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                paymentSheet.present(from: topViewController) { result in
                    continuation.resume(returning: result)
                }
            }
        }

        switch result {
        case .completed:
            await updateSubscriptionInProfile(tier: tier, subscriptionId: subscriptionId)
            showPaywall = false
            isSubscribed = true
            vm.insightsEnabled = true
            vm.loadCachedInsights()
            // Generate insights for every eligible procedure now that user is subscribed
            for group in vm.groupedByProcedure where group.entries.count >= 2 {
                guard let procedureId = group.entries.first?.procedureId,
                      vm.insights[procedureId] == nil else { continue }
                await vm.refreshInsights(for: procedureId, procedureName: group.key)
            }
        case .failed(let error):
            paymentErrorMessage = error.localizedDescription
            showPaymentError = true
        case .canceled:
            break
        }
    }

    private func updateSubscriptionInProfile(tier: SubscriptionTier, subscriptionId: String) async {
        do {
            guard let userId = supabase.auth.currentUser?.id else { return }
            try await supabase.database
                .from("user_profiles")
                .update([
                    "billing_plan": tier.rawValue,
                    "stripe_subscription_id": subscriptionId,
                    "subscription_status": "active",
                    "subscription_tier": tier.rawValue
                ])
                .eq("id", value: userId.uuidString.lowercased())
                .execute()
        } catch {
            print("Subscription profile update failed: \(error)")
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

private struct JournalStreakStrip: View {
    let streak: Int
    let dayNumber: Int
    let procedureName: String?

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(J.gradB)
                Text(streak > 0 ? "\(streak)-day streak" : "Start your streak")
                    .font(.custom("Outfit-SemiBold", size: 11))
                    .foregroundColor(J.textHi)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(J.cardWhite)
            .overlay(Capsule().stroke(J.border, lineWidth: J.strokeWidth))
            .clipShape(Capsule())

            Text(dayNumber > 0 ? "Day \(dayNumber)" : (procedureName ?? "Recovery journal"))
                .font(.custom("Outfit-Regular", size: 11))
                .foregroundColor(J.textLo)

            Spacer()
        }
    }
}

private struct JournalTodayCard: View {
    let latestEntry: JournalEntry?
    let procedureName: String?
    let onLogToday: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("TODAY'S JOURNAL")
                .font(.custom("Outfit-Regular", size: 9))
                .kerning(2.2)
                .foregroundColor(J.textLo)

            Text(headline)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(J.textHi)
                .lineSpacing(0)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.custom("Outfit-Regular", size: 13))
                .foregroundColor(J.textHi.opacity(0.72))
                .lineSpacing(3)

            HStack(spacing: 12) {
                if let latestEntry, let notes = latestEntry.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                    Text(notes)
                        .font(.custom("Outfit-Regular", size: 11))
                        .foregroundColor(J.textLo)
                        .lineLimit(2)
                } else {
                    Text("Add a photo, symptoms, or a quick note.")
                        .font(.custom("Outfit-Regular", size: 11))
                        .foregroundColor(J.textLo)
                }

                Spacer(minLength: 8)

                Button(action: onLogToday) {
                    Text("Log today")
                        .font(.custom("Outfit-SemiBold", size: 12))
                        .foregroundColor(J.textHi)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(J.cardWhite)
                        .overlay(Capsule().stroke(J.border, lineWidth: J.strokeWidth))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(J.reminderTint)
            .clipShape(RoundedRectangle(cornerRadius: J.cardRadius))
        }
        .padding(20)
        .background(J.cardWhite)
        .cornerRadius(J.heroRadius)
        .overlay(RoundedRectangle(cornerRadius: J.heroRadius).stroke(J.border, lineWidth: J.strokeWidth))
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
    }

    private var headline: String {
        if latestEntry != nil {
            return "How are you healing today?"
        }
        return "Start today's recovery note."
    }

    private var subtitle: String {
        if let procedureName {
            return "Keep your \(procedureName.lowercased()) report building with one quick check-in."
        }
        return "A quick entry helps Rena track your healing rhythm over time."
    }
}

private struct JournalPainTrendCard: View {
    let painSeries: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pain Trend")
                .font(.custom("Outfit-Regular", size: 10))
                .kerning(2.0)
                .foregroundColor(J.textHi)
                .textCase(.uppercase)

            HStack(alignment: .bottom, spacing: 7) {
                ForEach(chartValues.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(index == chartValues.count - 1 ? J.primary : J.primary.opacity(0.22))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(CGFloat(chartValues[index]) * 10, 14))
                }
            }
            .frame(height: 92, alignment: .bottom)
            .padding(.top, 2)

            Text(trendLabel)
                .font(.custom("Outfit-Regular", size: 11))
                .foregroundColor(J.textLo)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(J.cardWhite)
        .cornerRadius(J.cardRadius)
        .overlay(RoundedRectangle(cornerRadius: J.cardRadius).stroke(J.border, lineWidth: J.strokeWidth))
    }

    private var chartValues: [Int] {
        let values = Array(painSeries.suffix(5))
        return values.isEmpty ? [2, 4, 3, 2, 1] : values
    }

    private var trendLabel: String {
        guard painSeries.count >= 2 else { return "Keep logging to reveal a trend." }
        let recent = Array(painSeries.suffix(2))
        if recent[1] < recent[0] { return "Pain is easing in your latest logs." }
        if recent[1] > recent[0] { return "Pain is slightly higher in your latest logs." }
        return "Pain is holding steady right now."
    }
}

private struct JournalTodaySignalsCard: View {
    let pain: Int?
    let swelling: Int?
    let bruising: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Signals")
                .font(.custom("Outfit-Regular", size: 10))
                .kerning(2.0)
                .foregroundColor(J.textHi)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 12) {
                signalRow("Pain", value: pain)
                signalRow("Swelling", value: swelling)
                signalRow("Bruising", value: bruising)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(J.cardWhite)
        .cornerRadius(J.cardRadius)
        .overlay(RoundedRectangle(cornerRadius: J.cardRadius).stroke(J.border, lineWidth: J.strokeWidth))
    }

    private func signalRow(_ label: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.custom("Outfit-Regular", size: 11))
                    .foregroundColor(J.textLo)
                Spacer()
                Text(value.map { "\($0)/10" } ?? "--")
                    .font(.custom("Outfit-SemiBold", size: 12))
                    .foregroundColor(J.textHi)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(height: 6)
                    Capsule()
                        .fill(progressColor(for: label))
                        .frame(width: proxy.size.width * CGFloat((value ?? 0)) / 10.0, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func progressColor(for label: String) -> Color {
        switch label {
        case "Pain":
            return Color(hex: "#4D7A58")
        case "Swelling":
            return J.gradB
        default:
            return J.primary
        }
    }
}

private struct JournalAlertCard: View {
    let alert: JournalAlertSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: alert.severity.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(alert.severity == .warning || alert.severity == .urgent ? J.gradB : J.primary)
                Text("Smart Recovery Alert")
                    .font(.custom("Outfit-Regular", size: 10))
                    .kerning(2.0)
                    .foregroundColor(alert.severity == .warning || alert.severity == .urgent ? J.gradB : J.textHi)
                    .textCase(.uppercase)
            }

            Text(alert.title)
                .font(.custom("Outfit-SemiBold", size: 14))
                .foregroundColor(J.textHi)

            Text(alert.body)
                .font(.custom("Outfit-Regular", size: 12))
                .foregroundColor(J.textHi.opacity(0.72))
                .lineSpacing(3)

            if let metric = alert.metric {
                Text(metric)
                    .font(.custom("Outfit-SemiBold", size: 11))
                    .foregroundColor(J.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(J.primaryDim)
                    .clipShape(Capsule())
            }
        }
        .padding(15)
        .background(alert.severity == .warning || alert.severity == .urgent ? J.concernTint : J.positiveTint)
        .cornerRadius(J.cardRadius)
        .overlay(RoundedRectangle(cornerRadius: J.cardRadius).stroke(J.border, lineWidth: J.strokeWidth))
    }
}

private struct JournalWeeklyReportCard: View {
    let preview: JournalWeeklyReportPreview
    let onOpenReport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Report")
                    .font(.custom("Outfit-Regular", size: 10))
                    .kerning(2.0)
                    .foregroundColor(J.textHi)
                    .textCase(.uppercase)
                Spacer()
                Text(preview.statusLabel)
                    .font(.custom("Outfit-SemiBold", size: 10))
                    .foregroundColor(J.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(J.primaryDim)
                    .clipShape(Capsule())
            }

            Text(preview.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(J.textHi)

            Text(preview.subtitle)
                .font(.custom("Outfit-Regular", size: 13))
                .foregroundColor(J.textHi.opacity(0.72))
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(J.primary.opacity(0.12))
                        .frame(height: 8)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(J.primary)
                            .frame(width: proxy.size.width * CGFloat(preview.progress) / 100.0, height: 8)
                    }
                    .frame(height: 8)
                }
                .frame(height: 8)

                Text("\(preview.progress)% built")
                    .font(.custom("Outfit-Regular", size: 11))
                    .foregroundColor(J.textLo)
            }

            Button(action: onOpenReport) {
                HStack(spacing: 8) {
                    Text(preview.actionTitle)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.custom("Outfit-SemiBold", size: 13))
                .foregroundColor(.white)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(J.primary)
                .clipShape(Capsule())
            }
        }
        .padding(17)
        .background(J.cardWhite)
        .cornerRadius(J.cardRadius)
        .overlay(RoundedRectangle(cornerRadius: J.cardRadius).stroke(J.border, lineWidth: J.strokeWidth))
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
    }
}

private struct JournalPhotoReelSection: View {
    let entries: [JournalEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photo Reel")
                .font(.custom("Outfit-Regular", size: 10))
                .kerning(2.0)
                .foregroundColor(J.textHi)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(J.card.opacity(0.9))
                                .frame(width: 164, height: 146)
                                .overlay(
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Day \(entry.dayNumber)")
                                            .font(.custom("Outfit-SemiBold", size: 13))
                                            .foregroundColor(J.textHi)
                                        Text(entry.entryDate)
                                            .font(.custom("Outfit-Regular", size: 11))
                                            .foregroundColor(J.textLo)
                                        Spacer()
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.system(size: 19, weight: .medium))
                                            .foregroundColor(J.primary.opacity(0.55))
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                )
                        }
                    }
                }
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
                        InsightCard(type: .placeholder, message: "Log your first entry to unlock AI-powered recovery insights.")
                    } else if !isSubscribed {
                        InsightCard(
                            type: .locked,
                            message: "Upgrade to unlock AI-powered recovery insights personalized to your healing journey.",
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
                        InsightCard(type: .placeholder, message: "Keep logging entries to unlock AI-powered recovery insights.")
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
        HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                dayCell(date: date)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .background(J.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(J.border.opacity(0.72), lineWidth: J.strokeWidth))
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

        return VStack(alignment: .center, spacing: 5) {
            // Day name (e.g. "Mon")
            Text(dayName)
                .font(.custom("Outfit-Regular", size: 9))
                .foregroundColor(isToday ? J.primary : (isFuture ? J.textLo.opacity(0.4) : J.textLo))
                .fontWeight(isToday ? .semibold : .regular)

            // Day number — rounded square (borderRadius: 9) when active
            ZStack {
                if isToday {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(J.accent)
                        .frame(width: 30, height: 30)
                        .shadow(color: J.accent.opacity(0.24), radius: 4, x: 0, y: 2)
                } else if isTappable && hasEntry {
                    // Past day with entry — subtle filled background
                    RoundedRectangle(cornerRadius: 9)
                        .fill(J.accent.opacity(0.12))
                        .frame(width: 30, height: 30)
                }
                Text("\(dayNum)")
                    .font(.system(size: 13, weight: isToday ? .bold : .regular))
                    .foregroundColor(
                        isToday ? .white
                        : isFuture ? J.textLo.opacity(0.35)
                        : hasEntry ? J.primary
                        : J.textLo
                    )
            }
            .frame(width: 30, height: 30)

            // Entry dot
            Circle()
                .fill(hasEntry ? J.gradB : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isTappable else { return }
            onDateTap?(date)
        }
    }
}

// MARK: - Compact Entry Row

private struct CompactEntryRow: View {
    let entry: JournalEntry

    private static let entryKeyFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE · MMM d"; return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar (clips to card corners via clipShape below)
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)

            // Entry body
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.entryKeyFormatter.string(from: entry.entryDateAsDate) + (entry.dayNumber > 0 ? " · " + entry.dayLabel : ""))
                        .font(.custom("Outfit-Regular", size: 8.5))
                        .foregroundColor(J.textLo)

                    Text(entry.procedureName)
                        .font(.custom("Outfit-SemiBold", size: 13))
                        .foregroundColor(J.textHi)
                        .lineLimit(1)

                    if let notes = entry.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.custom("Outfit-Regular", size: 10.5))
                            .foregroundColor(J.textLo)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Circular arrow button (#8E4C5C dimmed bg)
                ZStack {
                    Circle()
                        .fill(J.primaryDim)
                        .frame(width: 24, height: 24)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(J.primary)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(J.cardWhite)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(J.border, lineWidth: J.strokeWidth))
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
    }

    private var accentColor: Color {
        // Cycle accent bar through brand colors by procedure name hash
        let colors: [Color] = [J.gradB, J.primary, J.accent, Color(hex: "#D4C4C6")]
        return colors[abs(entry.procedureName.hashValue) % colors.count]
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
