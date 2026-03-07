//
//  PhotoJournalView.swift
//  Renaissance Mobile
//
//  Main journal tab: procedure-grouped hero card list.
//

import SwiftUI

struct PhotoJournalView: View {
    @State private var vm = JournalViewModel()
    @State private var groupToDelete: (key: String, entries: [JournalEntry])?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if vm.isLoading && vm.entries.isEmpty {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if vm.entries.isEmpty {
                        emptyState
                    } else {
                        procedureList
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
                AddJournalEntryView(existingEntries: vm.entries) { procedureId, procedureName, dayNumber, entryDate, notes, photoData in
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

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .bottom) {
            Text("Recovery Journal")
                .font(Theme.Typography.homeHeader)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, 56)
        .padding(.bottom, Theme.Spacing.lg)
    }

    private var procedureList: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2)
                ],
                spacing: 2
            ) {
                ForEach(vm.groupedByProcedure, id: \.key) { group in
                    NavigationLink {
                        ProcedureEntriesView(procedureName: group.key, vm: vm)
                    } label: {
                        ProcedureGroupCard(group: group)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            groupToDelete = group
                        } label: {
                            Label("Delete Group", systemImage: "trash")
                        }
                    }
                }
            }
            Color.clear.frame(height: 100)
        }
        .padding(.top, Theme.Spacing.sm)
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

// MARK: - Procedure Group Card

private struct ProcedureGroupCard: View {
    let group: (key: String, entries: [JournalEntry])

    private var coverEntry: JournalEntry? { group.entries.last }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Photo — fills and crops to the fixed frame
            if let entry = coverEntry,
               let urlString = entry.photoUrl,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholderBg
                    }
                }
            } else {
                placeholderBg
            }

            // Gradient scrim
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .init(x: 0.5, y: 0.5),
                endPoint: .bottom
            )

            // Text at bottom
            VStack(alignment: .leading, spacing: 2) {
                let count = group.entries.count
                Text(group.key)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text("\(count) \(count == 1 ? "entry" : "entries")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .frame(height: 260)
        .clipped()
    }

    private var placeholderBg: some View {
        Rectangle()
            .fill(Theme.Brand.softBlush)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.Brand.dustyRose)
            )
    }
}

#Preview {
    PhotoJournalView()
}
