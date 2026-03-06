//
//  JournalTimelineCardView.swift
//  Renaissance Mobile
//

import SwiftUI

struct JournalTimelineCardView: View {
    let entry: JournalEntry
    var isAnalyzing: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.lg) {

            // Day indicator + timeline line
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(entry.hasAnalysis ? Theme.Brand.mauveBerry : Theme.Brand.softBlush)
                        .frame(width: 42, height: 42)
                    Text(entry.dayNumber == 0 ? "D0" : "D\(entry.dayNumber)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(entry.hasAnalysis ? .white : Theme.Brand.mauveBerry)
                }
                Rectangle()
                    .fill(Theme.Brand.softBlush)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 4)
            }

            // Card content
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {

                // Header row
                HStack {
                    Text(entry.dayLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Text(entry.entryDate, style: .date)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                // Photo thumbnail
                if let urlString = entry.photoUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                        case .failure:
                            photoPlaceholder
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                        @unknown default:
                            photoPlaceholder
                        }
                    }
                }

                // Notes preview
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }

                // Analysis summary bar
                if entry.hasAnalysis {
                    AnalysisMiniBar(entry: entry)
                } else if isAnalyzing {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Analyzing recovery…")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .fill(Color.white)
                    .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius,
                            x: Theme.Shadow.card.x, y: Theme.Shadow.card.y)
            )
            .padding(.bottom, Theme.Spacing.lg)
        }
    }

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
            .fill(Theme.Brand.softBlush)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.Brand.dustyRose)
            )
    }
}

// MARK: - Mini Analysis Bar

struct AnalysisMiniBar: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let summary = entry.summary {
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                MetricPill(label: "Swelling", value: entry.swellingIndex)
                MetricPill(label: "Bruising", value: entry.bruisingIndex)
                MetricPill(label: "Redness",  value: entry.rednessIndex)
                Spacer()
                if let overall = entry.overallScore {
                    Text(String(format: "%.0f%%", overall * 10))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Brand.mauveBerry)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .fill(Theme.Brand.palePink)
        )
    }
}

private struct MetricPill: View {
    let label: String
    let value: Double?

    var body: some View {
        if let value {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(String(format: "%.1f", value))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(pillColor(for: value))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white))
        }
    }

    private func pillColor(for value: Double) -> Color {
        if value < 3 { return Color(hex: "#10b981") }      // green — mild
        if value < 6 { return Color(hex: "#F59E0B") }      // amber — moderate
        return Color(hex: "#EF4444")                        // red — significant
    }
}
