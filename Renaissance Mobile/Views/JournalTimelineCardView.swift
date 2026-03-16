//
//  JournalTimelineCardView.swift
//  Renaissance Mobile
//

import SwiftUI

struct JournalTimelineCardView: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.lg) {

            // Day indicator + timeline line
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Theme.Brand.softBlush)
                        .frame(width: 42, height: 42)
                    Text(entry.dayNumber == 0 ? "D0" : "D\(entry.dayNumber)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Brand.mauveBerry)
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
                    Text(entry.entryDateAsDate, style: .date)
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

    private var photoPlaceholder: some View {  // keep for AsyncImage failure state
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

