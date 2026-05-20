//
//  JournalEntryDetailView.swift
//  Renaissance Mobile
//

import SwiftUI

// MARK: - Design tokens (violet cloud palette)

private enum D {
    static let bg       = Color(hex: "#EEEEFF")
    static let primary  = Color(hex: "#6C63FF")
    static let ink      = Color(hex: "#2D2575")
    static let muted    = Color(hex: "#7B6FC0")
    static let pale     = Color(hex: "#9C93C8")
    static let soft     = Color(hex: "#EAE7FF")
    static let line     = Color(hex: "#D4CCFF")
    static let cardBg   = Color.white
}

struct JournalEntryDetailView: View {
    let entry: JournalEntry
    var onDelete: () async -> Void

    @State private var showDeleteConfirm = false
    @State private var shareItems: [Any]?
    @State private var isPreparingShare = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Photo
                    if let urlString = entry.photoUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            default:
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(D.soft)
                                    .frame(height: 260)
                            }
                        }
                    }

                    // Metadata card
                    metadataCard

                    // Notes
                    if let notes = entry.notes, !notes.isEmpty {
                        notesSection(notes)
                    }

                    // Recovery Metrics
                    if entry.hasRecoveryMetrics {
                        metricsSection
                    }

                    // Actions
                    actionButtons

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
            }
        }
        .background(D.bg.ignoresSafeArea())
        .navigationBarHidden(true)
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

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Button { dismiss() } label: {
                Circle()
                    .fill(D.cardBg)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(D.ink)
                    )
                    .shadow(color: D.primary.opacity(0.12), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Journal Entry")
                .font(.custom("PlusJakartaSans-SemiBold", size: 18))
                .foregroundColor(D.ink)

            Spacer()

            // Balance the back button
            Circle()
                .fill(Color.clear)
                .frame(width: 38, height: 38)
        }
        .padding(.horizontal, 18)
        .padding(.top, 56)
        .padding(.bottom, 14)
    }

    // MARK: - Metadata Card

    private var metadataCard: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.procedureName)
                    .font(.custom("PlusJakartaSans-Bold", size: 20))
                    .foregroundColor(D.ink)

                HStack(spacing: 6) {
                    Text(entry.dayLabel)
                        .font(.custom("PlusJakartaSans-Medium", size: 12))
                        .foregroundColor(D.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(D.soft)
                        .clipShape(Capsule())

                    Text(entry.entryDateAsDate, style: .date)
                        .font(.custom("PlusJakartaSans-Regular", size: 12))
                        .foregroundColor(D.pale)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(D.cardBg)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(D.line.opacity(0.5), lineWidth: 1))
        .shadow(color: D.primary.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Notes

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Notes")
            Text(notes)
                .font(.custom("PlusJakartaSans-Regular", size: 15))
                .foregroundColor(D.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(D.cardBg)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(D.line.opacity(0.5), lineWidth: 1))
        .shadow(color: D.primary.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Recovery Metrics")
            VStack(spacing: 10) {
                if let level = entry.bruisingLevel, level > 0 {
                    MetricDisplayRow(label: "Bruising", value: Int(level), color: Color(hex: "#5B5BD6"))
                }
                if let level = entry.swellingLevel, level > 0 {
                    MetricDisplayRow(label: "Swelling", value: Int(level), color: Color(hex: "#7C73E6"))
                }
                if let level = entry.rednessLevel, level > 0 {
                    MetricDisplayRow(label: "Redness", value: Int(level), color: Color(hex: "#B76E79"))
                }
            }
        }
        .padding(16)
        .background(D.cardBg)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(D.line.opacity(0.5), lineWidth: 1))
        .shadow(color: D.primary.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await prepareShare() }
            } label: {
                HStack(spacing: 8) {
                    if isPreparingShare {
                        ProgressView().scaleEffect(0.85).tint(D.primary)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(isPreparingShare ? "Preparing…" : "Share Entry")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                }
                .foregroundColor(D.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(D.soft)
                .cornerRadius(14)
            }
            .disabled(isPreparingShare)
            .buttonStyle(.plain)

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Delete Entry")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                }
                .foregroundColor(Color(hex: "#EF4444"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color(hex: "#FEF2F2"))
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
            .tracking(1.2)
            .foregroundColor(D.pale)
    }

    // MARK: - Share

    @MainActor
    private func prepareShare() async {
        isPreparingShare = true
        defer { isPreparingShare = false }

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
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(label)
                    .font(.custom("PlusJakartaSans-Medium", size: 13))
                    .foregroundColor(Color(hex: "#2D2575"))
                Spacer()
                Text("\(value)/10 · \(levelLabel)")
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundColor(color)
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
        .padding(.vertical, 4)
    }
}
