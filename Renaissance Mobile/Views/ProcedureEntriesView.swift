//
//  ProcedureEntriesView.swift
//  Renaissance Mobile
//
//  Timeline view for all entries in a single procedure, with per-entry analysis modal.
//

import SwiftUI

// MARK: - Procedure Entries View

struct ProcedureEntriesView: View {
    let procedureName: String
    let vm: JournalViewModel

    @State private var analysisEntryId: UUID?

    private var entries: [JournalEntry] {
        vm.entries
            .filter { $0.procedureName == procedureName }
            .sorted { $0.dayNumber < $1.dayNumber }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    entryRow(entry: entry, isLast: index == entries.count - 1)
                }
                Color.clear.frame(height: 32)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle(procedureName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { analysisEntryId != nil },
            set: { if !$0 { analysisEntryId = nil } }
        )) {
            if let entryId = analysisEntryId,
               let liveEntry = vm.entries.first(where: { $0.id == entryId }) {
                EntryAnalysisSheet(
                    entry: liveEntry,
                    isAnalyzing: vm.analyzingEntryId == entryId,
                    onAnalyze: { await vm.analyzeEntry(liveEntry) }
                )
            }
        }
    }

    // MARK: - Entry Row

    @ViewBuilder
    private func entryRow(entry: JournalEntry, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {

            // Timeline column — plain day label, no circle
            VStack(spacing: 0) {
                Text(entry.dayNumber == 0 ? "D0" : "D\(entry.dayNumber)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(entry.hasAnalysis ? Theme.Brand.mauveBerry : Theme.Colors.textSecondary)
                    .frame(width: 36, height: 36)

                if !isLast {
                    Rectangle()
                        .fill(Theme.Brand.softBlush)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .frame(width: 36)

            // Photo card with chart icon overlay
            ZStack(alignment: .bottomTrailing) {
                NavigationLink {
                    JournalEntryDetailView(
                        entry: entry,
                        isAnalyzing: vm.analyzingEntryId == entry.id,
                        onAnalyze: { await vm.analyzeEntry(entry) },
                        onDelete:  { await vm.deleteEntry(entry) }
                    )
                } label: {
                    photoCard(entry: entry)
                }
                .buttonStyle(.plain)

                // Chart icon — bottom-right, no background circle
                Button {
                    analysisEntryId = entry.id
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                }
                .padding(14)
            }
            .padding(.bottom, isLast ? 0 : 12)
        }
    }

    // MARK: - Photo Card

    private func photoCard(entry: JournalEntry) -> some View {
        ZStack(alignment: .bottomLeading) {
            photoContent(for: entry)

            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .init(x: 0.5, y: 0.55),
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.entryDateAsDate, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 1)
                if vm.analyzingEntryId == entry.id {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.65).tint(.white)
                        Text("Analyzing…")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
        }
        .frame(height: 400)
        .frame(maxWidth: .infinity)
        .clipShape(Rectangle())
    }

    @ViewBuilder
    private func photoContent(for entry: JournalEntry) -> some View {
        if let urlString = entry.photoUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    photoPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            photoPlaceholder
        }
    }

    private var photoPlaceholder: some View {
        Rectangle()
            .fill(Theme.Brand.softBlush)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Brand.dustyRose)
            )
    }
}

// MARK: - Entry Analysis Sheet

struct EntryAnalysisSheet: View {
    let entry: JournalEntry
    var isAnalyzing: Bool
    var onAnalyze: () async -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {

                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.procedureName)
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        HStack {
                            Text(entry.dayLabel)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.Brand.mauveBerry)
                            Spacer()
                            Text(entry.entryDateAsDate, style: .date)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }

                    // Analyze / Re-analyze
                    if entry.photoUrl != nil {
                        HStack {
                            Spacer()
                            if isAnalyzing {
                                HStack(spacing: 8) {
                                    ProgressView().scaleEffect(0.85)
                                    Text("Analyzing recovery…")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                            } else {
                                Button {
                                    Task { await onAnalyze() }
                                } label: {
                                    Text(entry.hasAnalysis ? "Re-analyze" : "Analyze Photo")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Capsule().fill(Theme.Brand.mauveBerry))
                                }
                            }
                            Spacer()
                        }
                    }

                    if entry.hasAnalysis {

                        HStack(spacing: Theme.Spacing.sm) {
                            AnalysisScoreCard(label: "Swelling", value: entry.swellingIndex)
                            AnalysisScoreCard(label: "Bruising", value: entry.bruisingIndex)
                            AnalysisScoreCard(label: "Redness",  value: entry.rednessIndex)
                        }

                        if let overall = entry.overallScore {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Overall Recovery")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                    Spacer()
                                    Text(String(format: "%.0f%%", overall * 10))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Theme.Brand.mauveBerry)
                                }
                                ProgressView(value: overall / 10)
                                    .tint(Theme.Brand.mauveBerry)
                            }
                            .padding(Theme.Spacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                    .fill(Color.white)
                                    .shadow(color: Theme.Shadow.card.color,
                                            radius: Theme.Shadow.card.radius,
                                            x: Theme.Shadow.card.x,
                                            y: Theme.Shadow.card.y)
                            )
                        }

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
                                    .shadow(color: Theme.Shadow.card.color,
                                            radius: Theme.Shadow.card.radius,
                                            x: Theme.Shadow.card.x,
                                            y: Theme.Shadow.card.y)
                            )
                        }

                        Text("AI analysis is for personal tracking only and does not constitute medical advice.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.textSecondary)

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
                .padding(Theme.Spacing.xl)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("Recovery Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.Brand.mauveBerry)
                }
            }
        }
    }

    private func scoreColor(_ value: Double) -> Color {
        if value < 3 { return Color(hex: "#10b981") }
        if value < 6 { return Color(hex: "#F59E0B") }
        return Color(hex: "#EF4444")
    }
}

// MARK: - Analysis Score Card

struct AnalysisScoreCard: View {
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
                .shadow(color: Theme.Shadow.card.color,
                        radius: Theme.Shadow.card.radius,
                        x: Theme.Shadow.card.x,
                        y: Theme.Shadow.card.y)
        )
    }

    private func color(for v: Double) -> Color {
        if v < 3 { return Color(hex: "#10b981") }
        if v < 6 { return Color(hex: "#F59E0B") }
        return Color(hex: "#EF4444")
    }
}
