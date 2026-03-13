//
//  JournalEntryDetailView.swift
//  Renaissance Mobile
//

import SwiftUI

struct JournalEntryDetailView: View {
    let entry: JournalEntry
    var onDelete: () async -> Void

    @State private var showDeleteConfirm = false
    @State private var shareItems: [Any]?
    @State private var isPreparingShare = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {

                // Photo
                if let urlString = entry.photoUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 280)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
                        default:
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                .fill(Theme.Brand.softBlush)
                                .frame(height: 280)
                        }
                    }
                }

                // Metadata
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.procedureName)
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(entry.dayLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.Brand.dustyRose)
                    }
                    Spacer()
                    Text(entry.entryDateAsDate, style: .date)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                // Notes
                if let notes = entry.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        sectionLabel("Notes")
                        Text(notes)
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Share button
                Button {
                    Task { await prepareShare() }
                } label: {
                    HStack {
                        if isPreparingShare {
                            ProgressView().scaleEffect(0.85)
                                .tint(Theme.Brand.mauveBerry)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isPreparingShare ? "Preparing…" : "Share Entry")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Brand.mauveBerry)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                            .fill(Theme.Brand.mauveBerry.opacity(0.08))
                    )
                }
                .disabled(isPreparingShare)

                // Delete button
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Entry")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(hex: "#EF4444"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                            .fill(Color(hex: "#FEF2F2"))
                    )
                }
            }
            .padding(Theme.Spacing.xl)
        }
        .background(Color(hex: "#FAF7F5").ignoresSafeArea())
        .navigationTitle("Entry Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems {
                ActivityViewController(items: items)
                    .ignoresSafeArea()
            }
        }
        .confirmationDialog("Delete this journal entry?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await onDelete()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the photo and all data for this entry.")
        }
    }

    // MARK: - Share

    @MainActor
    private func prepareShare() async {
        isPreparingShare = true
        defer { isPreparingShare = false }

        // Load photo if available
        var loadedPhoto: UIImage?
        if let urlString = entry.photoUrl, let url = URL(string: urlString) {
            let data = try? await URLSession.shared.data(from: url).0
            loadedPhoto = data.flatMap { UIImage(data: $0) }
        }

        // Render branded card
        let card = ShareableEntryCard(entry: entry, photo: loadedPhoto)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        renderer.proposedSize = .init(width: 375, height: 470)

        guard let image = renderer.uiImage else { return }

        shareItems = [image, ShareableEntryCard.caption(for: entry)]
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.Colors.textSecondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}
