//
//  PhotoJournalView.swift
//  Renaissance Mobile
//

import SwiftUI

// MARK: - Page background

private let pageBackground = Color(hex: "#FAF7F5")

struct PhotoJournalView: View {
    var addEntryTrigger: Binding<Bool> = .constant(false)

    @State private var vm = JournalViewModel()
    @State private var groupToDelete: (key: String, entries: [JournalEntry])?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection

                if vm.isLoading && vm.entries.isEmpty {
                    Spacer()
                    ProgressView().tint(Theme.Brand.dustyRose)
                    Spacer()
                } else if vm.entries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(pageBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { procedureName in
                ProcedureEntriesView(procedureName: procedureName, vm: vm)
            }
            .sheet(isPresented: $vm.showAddEntry) {
                AddJournalEntryView(
                    existingEntries: vm.entries,
                    prefilledProcedureName: vm.pendingProcedureName
                ) { procedureId, procedureName, dayNumber, entryDate, notes, photoData in
                    await vm.addEntry(
                        procedureId: procedureId,
                        procedureName: procedureName,
                        dayNumber: dayNumber,
                        entryDate: entryDate,
                        notes: notes,
                        photoData: photoData
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
        .task { await vm.load() }
        .onChange(of: addEntryTrigger.wrappedValue) { _, triggered in
            if triggered {
                vm.tapAddEntry()
                addEntryTrigger.wrappedValue = false
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
            VStack(alignment: .leading, spacing: 3) {
                Text("Journal")
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundColor(Theme.Colors.textHomePrimary)
                if !vm.entries.isEmpty {
                    let count = vm.entries.count
                    Text("\(count) \(count == 1 ? "entry" : "entries")")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Theme.Colors.textHomeMuted)
                }
            }
            Spacer()
            Button { vm.tapAddEntry() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.Brand.mauveBerry)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.xxl)
        .padding(.bottom, Theme.Spacing.lg)
    }

    // MARK: - Entry List

    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {

                // Insights card
                let primaryGroup = vm.groupedByProcedure.max(by: { $0.entries.count < $1.entries.count })
                let primaryId = primaryGroup?.entries.first?.procedureId
                let primaryInsights = primaryId.flatMap { vm.insights[$0] }
                let isGenerating = primaryId.map { vm.insightsGenerating.contains($0) } ?? false
                let hasEnoughEntries = vm.groupedByProcedure.contains { $0.entries.count >= 2 }

                if hasEnoughEntries || isGenerating {
                    JournalInsightsCard(
                        insights: primaryInsights,
                        isGenerating: isGenerating,
                        procedureName: primaryGroup?.key
                    )
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xl)
                }

                // Month-grouped entry cards
                ForEach(entriesByMonth, id: \.month) { section in
                    // Month header
                    Text(section.month.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(Theme.Colors.textHomeMuted)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.md)
                        .padding(.bottom, Theme.Spacing.md)

                    // Cards
                    VStack(spacing: Theme.Spacing.md) {
                        ForEach(section.entries) { entry in
                            NavigationLink(value: entry.procedureName) {
                                EntryListRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    if let group = vm.groupedByProcedure.first(where: { $0.key == entry.procedureName }) {
                                        groupToDelete = group
                                    }
                                } label: {
                                    Label("Delete Group", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }

                Color.clear.frame(height: 40)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                Text("✦")
                    .font(.system(size: 36))
                    .foregroundColor(Theme.Brand.dustyRose.opacity(0.5))

                VStack(spacing: Theme.Spacing.sm) {
                    Text("Your Journal")
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundColor(Theme.Colors.textHomePrimary)

                    Text("Track your recovery, one day at a time.")
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(Theme.Colors.textHomeMuted)
                        .multilineTextAlignment(.center)
                }
            }

            Button { vm.tapAddEntry() } label: {
                Text("Begin First Entry")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Theme.Brand.charcoalRose)
                    .cornerRadius(Theme.CornerRadius.pill)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: - Helpers

    private var sortedEntries: [JournalEntry] {
        vm.entries.sorted { $0.entryDateAsDate > $1.entryDateAsDate }
    }

    private var entriesByMonth: [(month: String, entries: [JournalEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var monthOrder: [String] = []
        var grouped: [String: [JournalEntry]] = [:]
        for entry in sortedEntries {
            let key = formatter.string(from: entry.entryDateAsDate)
            if grouped[key] == nil {
                grouped[key] = []
                monthOrder.append(key)
            }
            grouped[key]!.append(entry)
        }
        return monthOrder.map { (month: $0, entries: grouped[$0]!) }
    }
}

// MARK: - AI Insights Card

private struct JournalInsightsCard: View {
    let insights: RecoveryInsights?
    let isGenerating: Bool
    let procedureName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {

            // Header
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Brand.dustyRose)
                Text("Rena Insights")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(Theme.Brand.dustyRose)
                Spacer()
                if let insights {
                    trendBadge(insights.trend)
                }
            }

            if isGenerating && insights == nil {
                HStack(spacing: Theme.Spacing.sm) {
                    ProgressView().scaleEffect(0.75).tint(Theme.Brand.dustyRose)
                    Text("Analyzing your recovery journey…")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            } else if let insights {
                Text(insights.summary)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)

                if !insights.flags.isEmpty {
                    Divider().background(.white.opacity(0.15))

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(insights.flags.prefix(2).enumerated()), id: \.offset) { _, flag in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: flag.severity.systemImage)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(flagColor(flag.severity))
                                    .frame(width: 14)
                                Text(flag.message)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if let encouragement = insights.encouragements.first {
                    Divider().background(.white.opacity(0.15))

                    HStack(alignment: .top, spacing: 6) {
                        Text("✦")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Brand.dustyRose)
                        Text(encouragement)
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

            } else {
                Text("Keep logging entries to unlock AI-powered recovery insights.")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(3)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Brand.charcoalRose)
        .cornerRadius(Theme.CornerRadius.large)
    }

    private func trendBadge(_ trend: TrendDirection) -> some View {
        HStack(spacing: 3) {
            Image(systemName: trend.systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(trend.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(trendColor(trend))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(trendColor(trend).opacity(0.2))
        .cornerRadius(Theme.CornerRadius.pill)
    }

    private func trendColor(_ trend: TrendDirection) -> Color {
        switch trend {
        case .improving:  return Color(hex: "#6EE7B7")
        case .stable:     return Theme.Brand.dustyRose
        case .concerning: return Color(hex: "#FCA5A5")
        }
    }

    private func flagColor(_ severity: FlagSeverity) -> Color {
        switch severity {
        case .info:    return Theme.Brand.dustyRose
        case .warning: return Color(hex: "#FCD34D")
        case .urgent:  return Color(hex: "#FCA5A5")
        }
    }
}

// MARK: - Entry List Row (card)

private struct EntryListRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(entry.procedureName)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundColor(Theme.Colors.textHomePrimary)
            Spacer()
            Text(entry.entryDateAsDate, style: .date)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Theme.Colors.textHomeMuted)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)
    }
}

#Preview {
    PhotoJournalView()
}
 Text(entry.procedureName)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundColor(Theme.Colors.textHomePrimary)
                    Spacer()
                    Text(entry.entryDateAsDate, style: .date)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Theme.Colors.textHomeMuted)
                }

                Text(entry.dayLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Brand.dustyRose)

                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(Theme.Colors.textHomeMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)
    }
}

#Preview {
    PhotoJournalView()
}
