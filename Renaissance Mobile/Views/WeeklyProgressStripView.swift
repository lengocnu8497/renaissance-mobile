//
//  WeeklyProgressStripView.swift
//  Renaissance Mobile
//
//  Horizontal scrollable timeline of week bubbles showing healing progress.
//  Used in PhotoJournalView and PostLoginHomeView.
//

import SwiftUI

struct WeeklyProgressStripView: View {
    let procedureName: String
    let checkIns: [WeeklyCheckIn]
    var onTapPending: (() -> Void)? = nil

    private let primary  = Color(hex: "#8E4C5C")
    private let gradA    = Color(hex: "#6B3346")
    private let gradB    = Color(hex: "#B76E79")
    private let accent   = Color(hex: "#C4929A")
    private let textHi   = Color(hex: "#3D2B2E")
    private let textLo   = Color(hex: "#B8A9AB")
    private let border   = Color(hex: "#C4929A").opacity(0.18)
    private let bg       = Color(hex: "#FFF8F6")

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(spacing: 8) {
                Text("Healing Timeline")
                    .font(.custom("Outfit-SemiBold", size: 14))
                    .foregroundColor(textHi)

                let completedCount = checkIns.filter(\.isCompleted).count
                Text("\(completedCount)/\(checkIns.count) weeks")
                    .font(.custom("Outfit-Regular", size: 11))
                    .foregroundColor(textLo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.12))
                    .clipShape(Capsule())

                Spacer()
            }

            // Week bubbles
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(checkIns) { checkIn in
                        WeekBubble(
                            checkIn: checkIn,
                            isPending: !checkIn.isCompleted && checkIn.scheduledDate <= Date(),
                            isFuture: checkIn.scheduledDate > Date(),
                            gradA: gradA,
                            gradB: gradB,
                            accent: accent,
                            textHi: textHi,
                            textLo: textLo,
                            border: border
                        )
                        .onTapGesture {
                            let isPending = !checkIn.isCompleted && checkIn.scheduledDate <= Date()
                            if isPending { onTapPending?() }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Week Bubble

private struct WeekBubble: View {
    let checkIn: WeeklyCheckIn
    let isPending: Bool
    let isFuture: Bool
    let gradA: Color
    let gradB: Color
    let accent: Color
    let textHi: Color
    let textLo: Color
    let border: Color

    @State private var pulsing = false

    private let size: CGFloat = 46

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                if checkIn.isCompleted {
                    // Gradient fill
                    Circle()
                        .fill(
                            LinearGradient(colors: [gradA, gradB],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                        .frame(width: size, height: size)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                } else if isPending {
                    // Pulsing ring — action needed
                    Circle()
                        .fill(gradB.opacity(0.12))
                        .frame(width: size, height: size)
                    Circle()
                        .stroke(gradB, lineWidth: 2)
                        .frame(width: size, height: size)
                        .scaleEffect(pulsing ? 1.08 : 1.0)
                        .opacity(pulsing ? 0.7 : 1.0)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulsing)
                        .onAppear { pulsing = true }
                    Text("\(checkIn.weekNumber)")
                        .font(.custom("Outfit-SemiBold", size: 14))
                        .foregroundColor(gradB)

                } else {
                    // Future — faded
                    Circle()
                        .stroke(border, lineWidth: 1.5)
                        .frame(width: size, height: size)
                    Text("\(checkIn.weekNumber)")
                        .font(.custom("Outfit-Regular", size: 13))
                        .foregroundColor(textLo.opacity(0.5))
                }
            }

            // Date label
            Text(weekShortLabel(checkIn.scheduledDate))
                .font(.custom("Outfit-Regular", size: 9))
                .foregroundColor(checkIn.isCompleted ? gradB.opacity(0.7) : textLo.opacity(0.6))
        }
        .frame(width: size + 8)
    }

    private func weekShortLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return fmt.string(from: date)
    }
}
