//
//  PhotoJournalView.swift
//  Renaissance Mobile
//
//  Main journal tab: procedure-grouped hero card list.
//

import SwiftUI

struct PhotoJournalView: View {
    @State private var vm = JournalViewModel()

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
            LazyVStack(spacing: 12) {
                ForEach(vm.groupedByProcedure, id: \.key) { group in
                    NavigationLink {
                        ProcedureEntriesView(procedureName: group.key, vm: vm)
                    } label: {
                        ProcedureGroupCard(group: group)
                    }
                    .buttonStyle(.plain)
                }
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
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

// MARK: - Procedure Group Card

private struct ProcedureGroupCard: View {
    let group: (key: String, entries: [JournalEntry])

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    // Show the most recent entry as the cover photo
    private var coverEntry: JournalEntry? { group.entries.last }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            photoContent

            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .init(x: 0.5, y: 0.55),
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(group.key)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 1)

                HStack(spacing: 6) {
                    let count = group.entries.count
                    Text("\(count) \(count == 1 ? "entry" : "entries")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))

                    if let first = group.entries.first {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("Started \(Self.dateFormatter.string(from: first.entryDateAsDate))")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 400)
        .clipShape(Rectangle())
    }

    @ViewBuilder
    private var photoContent: some View {
        if let entry = coverEntry,
           let urlString = entry.photoUrl,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Theme.Brand.softBlush)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Brand.dustyRose)
            )
    }
}

#Preview {
    PhotoJournalView()
}
