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

                // Recovery Metrics
                if entry.hasRecoveryMetrics {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        sectionLabel("Recovery Metrics")
                        VStack(spacing: 10) {
                            if let level = entry.bruisingLevel, level > 0 {
                                MetricDisplayRow(label: "Bruising", value: Int(level), color: Color(hex: "#7B4B6A"))
                            }
                            if let level = entry.swellingLevel, level > 0 {
                                MetricDisplayRow(label: "Swelling", value: Int(level), color: Color(hex: "#B76E79"))
                            }
                            if let level = entry.rednessLevel, level > 0 {
                                MetricDisplayRow(label: "Redness", value: Int(level), color: Color(hex: "#C4929A"))
                            }
                        }
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

// MARK: - Metric Display Row

private struct MetricDisplayRow: View {
    let label: String
    let value: Int
    let color: Color

    private var levelLabel: String {
        switch value {
        case 1...3: return "Mild"
        case 4...6: return "Moderate"
        case 7...9: return "Severe"
        case 10:    return "Extreme"
        default:    return "None"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text("\(value)/10 · \(levelLabel)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.12))
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value) / 10.0, height: 6)
                        .animation(.easeOut(duration: 0.6), value: value)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(Color(hex: "#FAF7F5"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.15), lineWidth: 1))
    }
}
