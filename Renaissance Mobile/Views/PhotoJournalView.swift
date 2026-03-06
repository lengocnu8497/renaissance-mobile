//
//  PhotoJournalView.swift
//  Renaissance Mobile
//
//  Main journal tab: procedure-grouped timeline of recovery entries.
//

import SwiftUI

struct PhotoJournalView: View {
    @State private var vm = JournalViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Brand.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    filterChips

                    if vm.isLoading && vm.entries.isEmpty {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if vm.entries.isEmpty {
                        emptyState
                    } else {
                        timeline
                    }
                }

                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            vm.tapAddEntry()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 58, height: 58)
                                .background(Circle().fill(Theme.Brand.mauveBerry))
                                .shadow(color: Theme.Shadow.glow.color,
                                        radius: Theme.Shadow.glow.radius,
                                        x: Theme.Shadow.glow.x,
                                        y: Theme.Shadow.glow.y)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $vm.showAddEntry) {
                AddJournalEntryView { procedureId, procedureName, dayNumber, entryDate, notes, photoData in
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
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recovery Journal")
                    .font(Theme.Typography.homeHeader)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Track your healing progress")
                    .font(Theme.Typography.heroSubtitle)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, 56)
        .padding(.bottom, Theme.Spacing.lg)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(
                    label: "All",
                    isSelected: vm.selectedProcedureId == nil
                ) {
                    vm.selectedProcedureId = nil
                    Task { await vm.load() }
                }

                ForEach(vm.proceduresWithEntries, id: \.id) { item in
                    FilterChip(
                        label: item.name,
                        isSelected: vm.selectedProcedureId == item.id
                    ) {
                        vm.selectedProcedureId = item.id
                        Task { await vm.load() }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.bottom, Theme.Spacing.md)
    }

    private var timeline: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(vm.groupedByProcedure, id: \.key) { group in
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        // Procedure group header
                        Text(group.key)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(.horizontal, Theme.Spacing.xl)
                            .padding(.top, Theme.Spacing.lg)

                        // Timeline entries
                        ForEach(group.entries) { entry in
                            NavigationLink {
                                JournalEntryDetailView(
                                    entry: entry,
                                    isAnalyzing: vm.analyzingEntryId == entry.id,
                                    onAnalyze: { await vm.analyzeEntry(entry) },
                                    onDelete:  { await vm.deleteEntry(entry) }
                                )
                            } label: {
                                JournalTimelineCardView(
                                    entry: entry,
                                    isAnalyzing: vm.analyzingEntryId == entry.id
                                )
                                .padding(.horizontal, Theme.Spacing.xl)
                            }
                        }
                    }
                }

                // Bottom padding for FAB
                Color.clear.frame(height: 100)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.Brand.softBlush)
                    .frame(width: 96, height: 96)
                Image(systemName: "camera.macro")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Brand.dustyRose)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("Start Your Journal")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Track your recovery with daily photos and AI-powered analysis of swelling, bruising, and redness.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                vm.tapAddEntry()
            } label: {
                Text("Add First Entry")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Theme.Brand.mauveBerry))
            }
            Spacer()
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : Theme.Colors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Theme.Brand.mauveBerry : Color.white)
                        .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius,
                                x: Theme.Shadow.card.x, y: Theme.Shadow.card.y)
                )
        }
    }
}

#Preview {
    PhotoJournalView()
}
