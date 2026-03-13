//
//  ProcedureEntriesView.swift
//  Renaissance Mobile
//
//  Card-based timeline view for all entries in a single procedure.
//

import SwiftUI

// MARK: - Procedure Entries View

struct ProcedureEntriesView: View {
    let procedureName: String
    let vm: JournalViewModel

    @State private var entryToDelete: JournalEntry?
    @State private var shareItems: [Any]?
    @State private var isPreparingShareFor: UUID?

    private var entries: [JournalEntry] {
        vm.entries
            .filter { $0.procedureName == procedureName }
            .sorted { $0.dayNumber > $1.dayNumber }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.lg) {
                ForEach(entries) { entry in
                    entryCard(entry: entry)
                }
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)
        }
        .background(Color(hex: "#FAF7F5").ignoresSafeArea())
        .navigationTitle(procedureName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: UUID.self) { entryId in
            if let entry = vm.entries.first(where: { $0.id == entryId }) {
                JournalEntryDetailView(
                    entry: entry,
                    onDelete: { await vm.deleteEntry(entry) }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { vm.tapAddEntry(for: procedureName) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.Brand.mauveBerry)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems {
                ActivityViewController(items: items).ignoresSafeArea()
            }
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(get: { entryToDelete != nil }, set: { if !$0 { entryToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let entry = entryToDelete else { return }
                entryToDelete = nil
                Task { await vm.deleteEntry(entry) }
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        } message: {
            Text("This will permanently delete the photo and all data for this entry.")
        }
    }

    // MARK: - Entry Card

    @ViewBuilder
    private func entryCard(entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Tappable area ─────────────────────────────────────────
            NavigationLink(value: entry.id) {
                VStack(alignment: .leading, spacing: 0) {
                    // Photo
                    if entry.photoUrl != nil {
                        photoContent(for: entry)
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .clipped()
                    }

                    // Notes
                    if let notes = entry.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.top, Theme.Spacing.lg)
                            .padding(.bottom, Theme.Spacing.md)
                    }
                }
            }
            .buttonStyle(.plain)

            // ── Divider ───────────────────────────────────────────────
            Divider()
                .background(Color(hex: "#F0EBE8"))

            // ── Date + menu row (outside NavigationLink) ──────────────
            HStack(alignment: .center) {
                Text(entry.entryDateAsDate, style: .date)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.Colors.textSecondary)

                Spacer()

                Menu {
                    Button {
                        Task { await shareEntry(entry) }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        entryToDelete = entry
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                } label: {
                    Group {
                        if isPreparingShareFor == entry.id {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Share

    @MainActor
    private func shareEntry(_ entry: JournalEntry) async {
        guard isPreparingShareFor == nil else { return }
        isPreparingShareFor = entry.id
        defer { isPreparingShareFor = nil }

        var loadedPhoto: UIImage?
        if let urlString = entry.photoUrl, let url = URL(string: urlString) {
            let data = try? await URLSession.shared.data(from: url).0
            loadedPhoto = data.flatMap { UIImage(data: $0) }
        }

        let card = ShareableEntryCard(entry: entry, photo: loadedPhoto)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        renderer.proposedSize = .init(width: 375, height: 470)

        guard let image = renderer.uiImage else { return }
        shareItems = [image, ShareableEntryCard.caption(for: entry)]
    }

    // MARK: - Photo helpers

    @ViewBuilder
    private func photoContent(for entry: JournalEntry) -> some View {
        if let urlString = entry.photoUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color(Theme.Brand.softBlush)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color(Theme.Brand.softBlush)
        }
    }
}
