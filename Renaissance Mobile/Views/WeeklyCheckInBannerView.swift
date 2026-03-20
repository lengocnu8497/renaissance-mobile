//
//  WeeklyCheckInBannerView.swift
//  Renaissance Mobile
//
//  Prominent banner shown when a weekly check-in is due.
//  Displayed in both PhotoJournalView and PostLoginHomeView.
//

import SwiftUI

struct WeeklyCheckInBannerView: View {
    let checkIn: WeeklyCheckIn
    let guide: WeeklyPhotoGuide
    let onBeginCheckIn: () -> Void
    let onSnooze: () -> Void

    private let gradA = Color(hex: "#6B3346")
    private let gradB = Color(hex: "#B76E79")
    private let textHi = Color(hex: "#3D2B2E")
    private let textLo = Color(hex: "#B8A9AB")
    private let bg     = Color(hex: "#FFF8F6")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Gradient header bar ────────────────────────────────────────────
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("WEEK \(checkIn.weekNumber) CHECK-IN")
                        .font(.custom("Outfit-SemiBold", size: 10))
                        .kerning(0.8)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.18))
                .clipShape(Capsule())

                Spacer()

                Text(weekLabel)
                    .font(.custom("Outfit-Regular", size: 10))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(colors: [gradA, gradB], startPoint: .leading, endPoint: .trailing)
            )

            // ── Body ──────────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 12) {
                // Context note
                Text(guide.contextNote)
                    .font(.custom("Outfit-Regular", size: 13))
                    .foregroundColor(textHi.opacity(0.7))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Angle chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(guide.angles, id: \.angle) { prompt in
                            AngleChip(prompt: prompt)
                        }
                    }
                }

                // Actions
                HStack(spacing: 10) {
                    Button(action: onBeginCheckIn) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Begin Check-In")
                                .font(.custom("Outfit-SemiBold", size: 13))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(colors: [gradA, gradB], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                    }

                    Button(action: onSnooze) {
                        Text("Later")
                            .font(.custom("Outfit-Regular", size: 13))
                            .foregroundColor(textLo)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(Color.black.opacity(0.04))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
            .background(bg)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gradB.opacity(0.22), lineWidth: 1))
        .shadow(color: Color(hex: "#6B3346").opacity(0.12), radius: 10, x: 0, y: 4)
    }

    private var weekLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "Due \(fmt.string(from: checkIn.scheduledDate))"
    }
}

// MARK: - Angle Chip

private struct AngleChip: View {
    let prompt: PhotoAnglePrompt
    private let primary = Color(hex: "#8E4C5C")

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: prompt.angle.systemImage)
                .font(.system(size: 9, weight: .semibold))
            Text(prompt.angle.displayName)
                .font(.custom("Outfit-SemiBold", size: 11))
        }
        .foregroundColor(primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(primary.opacity(0.09))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(primary.opacity(0.18), lineWidth: 1))
    }
}
