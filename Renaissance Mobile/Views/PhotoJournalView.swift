//
//  PhotoJournalView.swift
//  Renaissance Mobile
//

import SwiftUI
import Supabase

// MARK: - Design tokens — violet cloud palette

private enum J {
    static let pageBg    = Color(hex: "#F8F8FF")
    static let primary   = Color(hex: "#6C63FF")
    static let ink       = Color(hex: "#2D2575")
    static let muted     = Color(hex: "#7B6FC0")
    static let pale      = Color(hex: "#A9A3D4")
    static let soft      = Color(hex: "#EAE7FF")
    static let line      = Color(hex: "#D4CCFF")
    static let success   = Color(hex: "#5BBF84")
    static let cardWhite = Color.white
    static let border    = Color(hex: "#D4CCFF").opacity(0.55)
    static let shadowS   = (color: Color(hex: "#6C63FF").opacity(0.06), radius: CGFloat(6), x: CGFloat(0), y: CGFloat(2))
    static let cardRadius: CGFloat  = 22
    static let strokeWidth: CGFloat = 1
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

    @State private var vm = JournalViewModel()
    @State private var groupToDelete: (key: String, entries: [JournalEntry])?
    @State private var insightPresentation: InsightsPresentation? = nil
    @State private var showPhotoReel = false
    @State private var isSubscribed = false

    private let userProfileService = UserProfileService(supabase: supabase)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection

                if vm.isLoading && vm.entries.isEmpty {
                    Spacer()
                    ProgressView().tint(J.primary)
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
        .sheet(isPresented: $showPhotoReel) {
            HomePhotoReelView(entries: vm.photoReelEntries(limit: 1000))
        }
        .sheet(item: $insightPresentation) { pres in
            AllInsightsView(
                vm: vm,
                procedureId: pres.procedureId,
                procedureName: pres.procedureName,
                scrollAnchor: pres.scrollAnchor
            )
        }
        .task {
            await subscriptionStore.prepare()
            await vm.load()
            await refreshSubscriptionState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
            Task { await refreshSubscriptionState() }
        }
        .onChange(of: addEntryTrigger.wrappedValue) { _, triggered in
            if triggered {
                vm.tapAddEntry()
                addEntryTrigger.wrappedValue = false
            }
        }
        .onChange(of: vm.entries.count) { oldCount, newCount in
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
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            Text("Journal")
                .font(.custom("PlusJakartaSans-SemiBold", size: 22))
                .foregroundColor(J.ink)

            Spacer()

            Button { vm.tapAddEntry() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(J.primary)
                    .clipShape(Circle())
                    .shadow(color: J.primary.opacity(0.35), radius: 7, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 52)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var dayContextLine: some View {
        if let hero = vm.heroData {
            HStack(spacing: 8) {
                Text("Day \(hero.dayNumber)")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                    .foregroundColor(J.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(J.soft)
                    .clipShape(Capsule())

                Text("\(hero.procedureName) · Post-op")
                    .font(.custom("PlusJakartaSans-Medium", size: 13))
                    .foregroundColor(J.muted)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                dayContextLine

                JournalTodayCard(
                    hasLoggedToday: vm.hasLoggedToday,
                    latestEntry: vm.latestEntry,
                    procedureName: vm.primaryProcedureName,
                    onLogToday: { vm.tapAddEntry(for: vm.primaryProcedureName) }
                )
                .padding(.horizontal, 16)

                if vm.latestEntry != nil {
                    JournalTodaySignalsCard(
                        pain: vm.latestPainLevel,
                        swelling: vm.latestSwellingLevel,
                        bruising: vm.latestBruisingLevel,
                        redness: vm.latestRednessLevel
                    )
                    .padding(.horizontal, 16)
                }

                if let alert = vm.journalAlert {
                    JournalAlertCard(alert: alert)
                        .padding(.horizontal, 16)
                }

                if !vm.entries.isEmpty {
                    recentEntriesSection
                }

                JournalCalendarStrip(
                    weekDates: vm.currentWeekDates,
                    entryDates: Set(vm.entries.map(\.entryDate)),
                    onDateTap: { date in
                        let key = isoDate(date)
                        if !vm.entries.contains(where: { $0.entryDate == key }) {
                            vm.tapAddEntry()
                        }
                    }
                )
                .padding(.horizontal, 16)

                JournalPhotoReelSection(entries: vm.photoReelEntries(), onOpenGallery: { showPhotoReel = true })
                    .padding(.horizontal, 16)

                Color.clear.frame(height: 100)
            }
            .padding(.top, 8)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#F8F8FF"), Color(hex: "#EEEEFF")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Recent Entries Section

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent entries")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                    .foregroundColor(J.ink)
                Spacer()
                NavigationLink(value: AllEntriesRoute()) {
                    Text("See all →")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                        .foregroundColor(J.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Rectangle()
                .fill(J.line.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 16)

            ForEach(Array(sortedEntries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                VStack(spacing: 0) {
                    NavigationLink(value: entry.id) {
                        CompactEntryRow(entry: entry, isEmphasized: index == 0)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { deleteGroupButton(for: entry) }

                    if index < min(sortedEntries.count - 1, 4) {
                        Rectangle()
                            .fill(J.line.opacity(0.15))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
        .background(J.cardWhite)
        .cornerRadius(J.cardRadius)
        .overlay(RoundedRectangle(cornerRadius: J.cardRadius).stroke(J.border, lineWidth: J.strokeWidth))
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
        .padding(.horizontal, 16)
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

            vm.loadCachedInsights()
            vm.loadCachedWeeklySummaries()
            await vm.loadRemoteWeeklySummaries()

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

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: weekDates.first ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your check-in rhythm")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                    .foregroundColor(J.ink)
                Spacer()
                Text(monthLabel)
                    .font(.custom("PlusJakartaSans-Medium", size: 12))
                    .foregroundColor(J.muted)
            }

            HStack(spacing: 8) {
                ForEach(weekDates, id: \.self) { date in
                    dayCell(date: date)
                }
            }
        }
        .padding(18)
        .background(J.cardWhite)
        .cornerRadius(J.cardRadius)
        .overlay(RoundedRectangle(cornerRadius: J.cardRadius).stroke(J.border, lineWidth: J.strokeWidth))
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
        let todayLogged = isToday && hasEntry

        return VStack(alignment: .center, spacing: 8) {
            Text(dayName)
                .font(.custom("PlusJakartaSans-Regular", size: 10))
                .foregroundColor(
                    isToday ? J.primary
                    : hasEntry ? J.primary
                    : isFuture ? J.pale
                    : J.muted
                )
                .fontWeight((isToday || hasEntry) ? .semibold : .regular)

            VStack(spacing: 8) {
                Text("\(dayNum)")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                    .foregroundColor(
                        todayLogged ? .white
                        : isToday ? J.primary
                        : isFuture ? J.pale
                        : hasEntry ? J.primary
                        : J.muted
                    )

                Circle()
                    .fill(hasEntry && !todayLogged ? J.primary : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(cellBackground(isToday: isToday, hasEntry: hasEntry, isFuture: isFuture))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                Group {
                    if isToday && !hasEntry {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(J.primary, lineWidth: 1.5)
                    }
                }
            )
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isFuture else { return }
            onDateTap?(date)
        }
    }

    private func cellBackground(isToday: Bool, hasEntry: Bool, isFuture: Bool) -> Color {
        if isToday && hasEntry { return J.primary }
        if isToday { return J.soft }
        if hasEntry { return Color.white.opacity(0.95) }
        if isFuture { return Color.white.opacity(0.4) }
        return Color.white.opacity(0.7)
    }
}

// MARK: - Compact Entry Row

private struct CompactEntryRow: View {
    let entry: JournalEntry
    var isEmphasized: Bool = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    private var notePreview: String {
        let trimmed = entry.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "No notes recorded" : trimmed
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(entry.entryDateAsDate)
    }

    private var timeLabel: String {
        if isToday { return "Just logged" }
        if Calendar.current.isDateInYesterday(entry.entryDateAsDate) { return "Yesterday" }
        return Self.dateFormatter.string(from: entry.entryDateAsDate)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(isToday ? "Today" : "Day \(entry.dayNumber)")
                .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                .foregroundColor(isToday ? .white : J.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isToday ? J.success : J.soft)
                .clipShape(Capsule())
                .frame(minWidth: 54, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.procedureName)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                    .foregroundColor(J.ink)
                    .lineLimit(1)

                Text(notePreview)
                    .font(.custom("PlusJakartaSans-Regular", size: 11))
                    .foregroundColor(J.muted)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(timeLabel)
                    .font(.custom("PlusJakartaSans-Regular", size: 10))
                    .foregroundColor(isToday ? J.success : J.pale)
                    .fontWeight(isToday ? .semibold : .regular)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(J.pale)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    PhotoJournalView()
}
