//
//  JournalEntryDetailView.swift
//  Renaissance Mobile
//

import SwiftUI

struct JournalEntryDetailView: View {
    let entry: JournalEntry
    var isAnalyzing: Bool
    var onAnalyze: () async -> Void
    var onDelete: () async -> Void

    @State private var showDeleteConfirm = false
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
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.procedureName)
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(entry.dayLabel)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.Brand.mauveBerry)
                    }
                    Spacer()
                    Text(entry.entryDateAsDate, style: .date)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                // Notes
                if let notes = entry.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        sectionLabel("Your Notes")
                        Text(notes)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                }

                // Analysis section
                analysisSection

                // Delete
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
                .padding(.top, Theme.Spacing.md)
            }
            .padding(Theme.Spacing.xl)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("Entry Detail")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Analysis

    @ViewBuilder
    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                sectionLabel("Recovery Analysis")
                Spacer()
                if entry.photoUrl != nil {
                    if isAnalyzing {
                        ProgressView().scaleEffect(0.85)
                    } else {
                        Button {
                            Task { await onAnalyze() }
                        } label: {
                            Text(entry.hasAnalysis ? "Re-analyze" : "Analyze Photo")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.Brand.mauveBerry)
                        }
                    }
                }
            }

            if entry.hasAnalysis {
                // Score cards
                HStack(spacing: Theme.Spacing.sm) {
                    ScoreCard(label: "Swelling", value: entry.swellingIndex)
                    ScoreCard(label: "Bruising", value: entry.bruisingIndex)
                    ScoreCard(label: "Redness",  value: entry.rednessIndex)
                }

                // Overall progress bar
                if let overall = entry.overallScore {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Overall Recovery")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Spacer()
                            Text(String(format: "%.0f%%", overall * 10))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.Brand.mauveBerry)
                        }
                        ProgressView(value: overall / 10)
                            .tint(Theme.Brand.mauveBerry)
                    }
                    .padding(Theme.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                            .fill(Color.white)
                            .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius,
                                    x: Theme.Shadow.card.x, y: Theme.Shadow.card.y)
                    )
                }

                // Summary
                if let summary = entry.summary {
                    Text(summary)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(Theme.Spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                .fill(Theme.Brand.palePink)
                        )
                }

                // Zone breakdown
                if let zones = entry.zones, !zones.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Zone Breakdown")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        ForEach(zones) { zone in
                            HStack {
                                Text(zone.zone.capitalized)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                Text(String(format: "%.1f", zone.score))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(scoreColor(zone.score))
                                    .frame(width: 36, alignment: .trailing)
                            }
                            if let notes = zone.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .padding(.leading, Theme.Spacing.sm)
                            }
                            if zone.id != zones.last?.id { Divider() }
                        }
                    }
                    .padding(Theme.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                            .fill(Color.white)
                            .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius,
                                    x: Theme.Shadow.card.x, y: Theme.Shadow.card.y)
                    )
                }

                // Disclaimer
                Text("AI analysis is for personal tracking only and does not constitute medical advice. Contact your provider with any concerns.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, Theme.Spacing.sm)

            } else if entry.photoUrl == nil {
                Text("Add a photo to enable AI recovery analysis.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(Theme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .fill(Theme.Brand.palePink)
                    )
            }
        }
    }

    private func scoreColor(_ value: Double) -> Color {
        if value < 3 { return Color(hex: "#10b981") }
        if value < 6 { return Color(hex: "#F59E0B") }
        return Color(hex: "#EF4444")
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.Colors.textSecondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

// MARK: - Score Card

private struct ScoreCard: View {
    let label: String
    let value: Double?

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
            if let v = value {
                Text(String(format: "%.1f", v))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(color(for: v))
            } else {
                Text("—")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Text("/ 10")
                .font(.system(size: 10))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .fill(Color.white)
                .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius,
                        x: Theme.Shadow.card.x, y: Theme.Shadow.card.y)
        )
    }

    private func color(for v: Double) -> Color {
        if v < 3 { return Color(hex: "#10b981") }
        if v < 6 { return Color(hex: "#F59E0B") }
        return Color(hex: "#EF4444")
    }
}
