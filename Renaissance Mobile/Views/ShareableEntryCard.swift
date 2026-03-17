//
//  ShareableEntryCard.swift
//  Renaissance Mobile
//
//  Branded card rendered to UIImage for social sharing.
//  Designed for 4:5 portrait (375 × 470 pt @ 3x).
//

import SwiftUI

// MARK: - Shareable Card View

struct ShareableEntryCard: View {
    let entry: JournalEntry
    let photo: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            photoSection
            contentSection
            brandingFooter
        }
        .frame(width: 375, height: 470)
        .background(Color(hex: "#FAF7F5"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: Photo / hero section

    @ViewBuilder
    private var photoSection: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: 375, height: 280)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    dayBadge
                        .padding(16)
                }
        } else {
            // Gradient hero when no photo
            LinearGradient(
                colors: [Theme.Brand.softBlush, Theme.Brand.dustyRose.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: 375, height: 220)
            .overlay(alignment: .bottomLeading) {
                dayBadge
                    .padding(16)
            }
        }
    }

    private var dayBadge: some View {
        Text(entry.dayLabel.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.45))
            .clipShape(Capsule())
    }

    // MARK: Content section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.procedureName)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)

            if let notes = entry.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(Theme.Colors.textHomeMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(entry.entryDateAsDate, style: .date)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Theme.Colors.textHomeMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: Branding footer

    private var brandingFooter: some View {
        HStack {
            HStack(spacing: 5) {
                Text("✦")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Brand.dustyRose)
                Text("Rena Aesthetic Lab")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            Spacer()
            Text("Available on the App Store")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(Theme.Colors.textHomeMuted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.Brand.softBlush.opacity(0.4))
    }
}

// MARK: - Share Caption

extension ShareableEntryCard {
    /// Composed caption with hashtags and app discovery hook.
    static func caption(for entry: JournalEntry) -> String {
        let procedureTag = entry.procedureName
            .components(separatedBy: .whitespaces)
            .map { $0.capitalized }
            .joined()

        let dayLine = entry.dayNumber == 0
            ? "Day of procedure"
            : "Day \(entry.dayNumber) of recovery"

        return """
        \(dayLine) — \(entry.procedureName) 🌸

        Tracking my healing journey with Rena Aesthetic Lab.

        Download on the App Store — search "Rena Aesthetic Lab" ✦

        #RenaAestheticLab #RecoveryJourney #\(procedureTag)Recovery #PostOpRecovery #AestheticCommunity #HealingJourney
        """
    }
}

// MARK: - Activity View Controller wrapper

struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
