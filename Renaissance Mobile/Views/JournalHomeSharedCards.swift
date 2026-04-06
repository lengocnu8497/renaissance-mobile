//
//  JournalHomeSharedCards.swift
//  Renaissance Mobile
//

import SwiftUI

enum JournalCardsUI {
    static let primary = Color(hex: "#516048")
    static let accent = Color(hex: "#B07B7A")
    static let roseSoft = Color(hex: "#F1DDDA")
    static let textHi = Color(hex: "#1F261D")
    static let textLo = Color(hex: "#687064")
    static let card = Color(hex: "#EDF1E8")
    static let cardWhite = Color.white
    static let border = Color.black.opacity(0.05)
    static let shadowS = (
        color: Color(red: 90 / 255, green: 103 / 255, blue: 80 / 255).opacity(0.08),
        radius: CGFloat(7),
        x: CGFloat(0),
        y: CGFloat(2)
    )
    static let cardRadius: CGFloat = 18
    static let heroRadius: CGFloat = 24
    static let strokeWidth: CGFloat = 1
}

struct AllEntriesRoute: Hashable {}

struct JournalStreakStrip: View {
    let streak: Int
    let dayNumber: Int
    let procedureName: String?

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DAILY STREAK")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .kerning(2.0)
                    .foregroundColor(JournalCardsUI.textLo)

                HStack(spacing: 6) {
                    Text(streak > 0 ? "\(streak) days" : "Start today")
                        .font(.custom("Manrope", size: 24))
                        .fontWeight(.bold)
                        .foregroundColor(JournalCardsUI.accent)

                    if streak > 0 {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(JournalCardsUI.accent)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Your consistency metric")
                        .font(.custom("PlusJakartaSans-Regular", size: 11))
                        .foregroundColor(JournalCardsUI.textLo)
                    Text("\(habitStrength)%")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                        .foregroundColor(JournalCardsUI.textLo)
                }

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 132, height: 10)
                    Capsule()
                        .fill(JournalCardsUI.primary)
                        .frame(width: 132 * CGFloat(habitStrength) / 100.0, height: 10)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: JournalCardsUI.cardRadius)
                .stroke(JournalCardsUI.border, lineWidth: JournalCardsUI.strokeWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: JournalCardsUI.cardRadius, style: .continuous))
        .shadow(
            color: JournalCardsUI.shadowS.color,
            radius: JournalCardsUI.shadowS.radius,
            x: JournalCardsUI.shadowS.x,
            y: JournalCardsUI.shadowS.y
        )
    }

    private var habitStrength: Int {
        let base = streak > 0 ? min(92, 52 + streak * 5) : 24
        return max(12, base)
    }
}

struct JournalTodayCard: View {
    let latestEntry: JournalEntry?
    let procedureName: String?
    let onLogToday: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headlineBlock(maxWidth: nil, bodyMaxWidth: nil)

            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QUICK ENTRY")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                            .kerning(2.0)
                            .foregroundColor(JournalCardsUI.textLo)
                        Text("Pain, notes, and a photo")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                            .foregroundColor(JournalCardsUI.primary)
                    }

                    Spacer()

                    Button(action: onLogToday) {
                        Text("Add entry")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                            .foregroundColor(.white)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 11)
                            .background(JournalCardsUI.primary)
                            .clipShape(Capsule())
                    }
                }

                VStack(spacing: 11) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("PAIN")
                                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                                .kerning(1.8)
                                .foregroundColor(JournalCardsUI.textLo)
                            Spacer()
                            Text("\(painValue)/10")
                                .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                                .foregroundColor(JournalCardsUI.textLo)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(JournalCardsUI.card)
                                Capsule()
                                    .fill(painValue <= 3 ? Color(hex: "#4D7A58") : JournalCardsUI.accent)
                                    .frame(width: proxy.size.width * CGFloat(painValue) / 10.0)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: JournalCardsUI.cardRadius, style: .continuous))

                    HStack(spacing: 10) {
                        quickPromptCard(
                            title: "NOTES PROMPT",
                            body: latestEntry?.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                                ? "What feels different from your last entry?"
                                : "What feels better today?"
                        )
                        quickPromptCard(
                            title: "PHOTO",
                            body: "Add daylight comparison"
                        )
                    }
                }
            }
            .padding(14)
            .background(Color(hex: "#F3F6EE"))
            .clipShape(RoundedRectangle(cornerRadius: JournalCardsUI.heroRadius, style: .continuous))
        }
        .padding(18)
        .background(JournalCardsUI.cardWhite)
        .cornerRadius(JournalCardsUI.heroRadius)
        .overlay(
            RoundedRectangle(cornerRadius: JournalCardsUI.heroRadius)
                .stroke(JournalCardsUI.border, lineWidth: JournalCardsUI.strokeWidth)
        )
        .shadow(
            color: JournalCardsUI.shadowS.color,
            radius: JournalCardsUI.shadowS.radius,
            x: JournalCardsUI.shadowS.x,
            y: JournalCardsUI.shadowS.y
        )
    }

    private var painValue: Int {
        let rawPain = latestEntry?.painLevel ?? 2
        return max(0, min(10, Int(rawPain)))
    }

    private func headlineBlock(maxWidth: CGFloat?, bodyMaxWidth: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY'S JOURNAL")
                .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                .kerning(2.3)
                .foregroundColor(JournalCardsUI.textLo)

            Text("Log today's recovery in under a minute.")
                .font(.custom("Manrope", size: 27))
                .fontWeight(.heavy)
                .foregroundColor(JournalCardsUI.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: maxWidth, alignment: .leading)
        }
    }

    private func quickPromptCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                .kerning(1.8)
                .foregroundColor(JournalCardsUI.textLo)
            Text(body)
                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                .foregroundColor(JournalCardsUI.primary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 13)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: JournalCardsUI.cardRadius, style: .continuous))
    }
}

struct JournalRecoveryScoreCard: View {
    let score: RecoveryScoreSnapshot?

    var body: some View {
        if let score {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recovery score")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                        .kerning(2.0)
                        .foregroundColor(JournalCardsUI.textLo)
                        .textCase(.uppercase)

                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(score.score)")
                            .font(.custom("Manrope", size: 34))
                            .fontWeight(.bold)
                            .foregroundColor(JournalCardsUI.accent)
                        Text("/100")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                            .foregroundColor(JournalCardsUI.textLo)
                    }

                    Text(scoreCaption(for: score))
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundColor(JournalCardsUI.textLo)
                        .lineSpacing(3)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 10) {
                    scoreMetric(
                        title: "Consistency",
                        value: "\(score.consistencyRate)%"
                    )
                    scoreMetric(
                        title: "Symptom trend",
                        value: score.symptomTrend.label
                    )
                }
            }
            .padding(18)
            .background(JournalCardsUI.card)
            .cornerRadius(28)
        }
    }

    private func scoreMetric(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(title)
                .font(.custom("PlusJakartaSans-Regular", size: 11))
                .foregroundColor(JournalCardsUI.textLo)
            Text(value)
                .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                .foregroundColor(JournalCardsUI.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(JournalCardsUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func scoreCaption(for score: RecoveryScoreSnapshot) -> String {
        "\(score.consistencyRate)% consistency and \(score.symptomTrend.label.lowercased()) symptoms based on your latest entries."
    }
}

struct JournalPainTrendCard: View {
    let painSeries: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("Pain trend")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .kerning(2.0)
                    .foregroundColor(JournalCardsUI.textLo)
                    .textCase(.uppercase)
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(JournalCardsUI.primary)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(chartValues.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 18)
                        .fill(index == chartValues.count - 1 ? JournalCardsUI.primary : JournalCardsUI.primary.opacity(0.18 + (Double(index) * 0.04)))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(CGFloat(chartValues[index]) * 10, 18))
                }
            }
            .frame(height: 96, alignment: .bottom)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(JournalCardsUI.cardWhite)
        .cornerRadius(28)
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(JournalCardsUI.border, lineWidth: JournalCardsUI.strokeWidth))
        .shadow(
            color: JournalCardsUI.shadowS.color,
            radius: JournalCardsUI.shadowS.radius,
            x: JournalCardsUI.shadowS.x,
            y: JournalCardsUI.shadowS.y
        )
    }

    private var chartValues: [Int] {
        let values = Array(painSeries.suffix(5))
        return values.isEmpty ? [9, 7, 5, 3, 2] : values
    }
}

struct JournalTodaySignalsCard: View {
    let pain: Int?
    let swelling: Int?
    let bruising: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today's signals")
                .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                .kerning(2.0)
                .foregroundColor(JournalCardsUI.textLo)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 14) {
                signalRow("Pain", value: pain)
                signalRow("Swelling", value: swelling)
                signalRow("Bruising", value: bruising)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(JournalCardsUI.card)
        .cornerRadius(28)
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(JournalCardsUI.border, lineWidth: JournalCardsUI.strokeWidth))
        .shadow(
            color: JournalCardsUI.shadowS.color,
            radius: JournalCardsUI.shadowS.radius,
            x: JournalCardsUI.shadowS.x,
            y: JournalCardsUI.shadowS.y
        )
    }

    private func signalRow(_ label: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(label)
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundColor(JournalCardsUI.textLo)
                Spacer()
                Text(value.map { "\($0)/10" } ?? "--")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                    .foregroundColor(JournalCardsUI.textHi)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white)
                        .frame(height: 7)
                    Capsule()
                        .fill(progressColor(for: label))
                        .frame(width: proxy.size.width * CGFloat((value ?? 0)) / 10.0, height: 7)
                }
            }
            .frame(height: 7)
        }
    }

    private func progressColor(for label: String) -> Color {
        switch label {
        case "Pain":
            return Color(hex: "#4D7A58")
        case "Swelling":
            return JournalCardsUI.accent
        default:
            return JournalCardsUI.primary
        }
    }
}

struct JournalAlertCard: View {
    let alert: JournalAlertSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: alert.severity.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#A85555"))
                )

            VStack(alignment: .leading, spacing: 8) {
                Text("Smart Recovery Alert")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .kerning(2.1)
                    .foregroundColor(Color(hex: "#A85555"))
                    .textCase(.uppercase)

                Text(alert.title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                    .foregroundColor(JournalCardsUI.textHi)

                Text(alert.body)
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .foregroundColor(JournalCardsUI.textLo)
                    .lineSpacing(5)

                if let metric = alert.metric {
                    Text(metric)
                        .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                        .foregroundColor(JournalCardsUI.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.7))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(JournalCardsUI.roseSoft)
        .cornerRadius(28)
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(JournalCardsUI.border, lineWidth: JournalCardsUI.strokeWidth))
        .shadow(
            color: JournalCardsUI.shadowS.color,
            radius: JournalCardsUI.shadowS.radius,
            x: JournalCardsUI.shadowS.x,
            y: JournalCardsUI.shadowS.y
        )
    }
}

struct JournalWeeklyReportCard: View {
    let preview: JournalWeeklyReportPreview
    let onOpenReport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Report")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .kerning(2.0)
                    .foregroundColor(JournalCardsUI.textLo)
                    .textCase(.uppercase)
                Spacer()
                Text(preview.statusLabel)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .foregroundColor(JournalCardsUI.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(JournalCardsUI.card)
                    .clipShape(Capsule())
            }

            Text(preview.title)
                .font(.custom("Manrope", size: 27))
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#314030"))

            Text(preview.subtitle)
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundColor(JournalCardsUI.textLo)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(JournalCardsUI.primary.opacity(0.12))
                        .frame(height: 8)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(JournalCardsUI.primary)
                            .frame(width: proxy.size.width * CGFloat(preview.progress) / 100.0, height: 8)
                    }
                    .frame(height: 8)
                }
                .frame(height: 8)

                Text("Report \(preview.progress)% ready")
                    .font(.custom("PlusJakartaSans-Regular", size: 11))
                    .foregroundColor(JournalCardsUI.textLo)
            }

            Button(action: onOpenReport) {
                HStack(spacing: 8) {
                    Text(preview.actionTitle)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                .foregroundColor(Color(hex: "#314030"))
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Color(hex: "#D9E3CE"))
                .clipShape(Capsule())
            }
        }
        .padding(20)
        .background(JournalCardsUI.cardWhite)
        .cornerRadius(28)
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(JournalCardsUI.border, lineWidth: JournalCardsUI.strokeWidth))
        .shadow(
            color: JournalCardsUI.shadowS.color,
            radius: JournalCardsUI.shadowS.radius,
            x: JournalCardsUI.shadowS.x,
            y: JournalCardsUI.shadowS.y
        )
    }
}

struct JournalPhotoReelSection: View {
    let entries: [JournalEntry]
    var onOpenGallery: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Photo Reel")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                        .kerning(2.0)
                        .foregroundColor(JournalCardsUI.textLo)
                        .textCase(.uppercase)

                    Text("Recent captures")
                        .font(.custom("Manrope", size: 22))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#314030"))
                }

                Spacer()

                Group {
                    if let onOpenGallery {
                        Button(action: onOpenGallery) {
                            galleryLabel
                        }
                    } else {
                        NavigationLink(value: AllEntriesRoute()) {
                            galleryLabel
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if entries.isEmpty {
                        ForEach(["Day 1", "Day 7", "Day 14"], id: \.self) { label in
                            placeholderPhotoCard(label: label)
                        }
                    } else {
                        ForEach(entries) { entry in
                            photoCard(entry: entry)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(JournalCardsUI.cardWhite)
        .cornerRadius(28)
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(JournalCardsUI.border, lineWidth: JournalCardsUI.strokeWidth))
        .shadow(
            color: JournalCardsUI.shadowS.color,
            radius: JournalCardsUI.shadowS.radius,
            x: JournalCardsUI.shadowS.x,
            y: JournalCardsUI.shadowS.y
        )
    }

    private func photoCard(entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(photoFill(for: entry))
                .frame(width: 116, height: 132)
                .overlay(
                    Group {
                        if entry.photoUrl != nil || entry.photoPath != nil {
                            Image(systemName: "photo")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(JournalCardsUI.primary.opacity(0.45))
                        }
                    }
                )

            Text("Day \(entry.dayNumber)")
                .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                .foregroundColor(JournalCardsUI.textHi)

            Text(entry.entryDateAsDate.formatted(.dateTime.month(.abbreviated).day()))
                .font(.custom("PlusJakartaSans-Regular", size: 11))
                .foregroundColor(JournalCardsUI.textLo)
        }
        .frame(width: 116, alignment: .leading)
    }

    private func placeholderPhotoCard(label: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(JournalCardsUI.card)
                .frame(width: 116, height: 132)

            Text(label)
                .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                .foregroundColor(JournalCardsUI.textHi)

            Text("Add a photo")
                .font(.custom("PlusJakartaSans-Regular", size: 11))
                .foregroundColor(JournalCardsUI.textLo)
        }
        .frame(width: 116, alignment: .leading)
    }

    private func photoFill(for entry: JournalEntry) -> Color {
        let palette: [Color] = [JournalCardsUI.card, JournalCardsUI.roseSoft, Color(hex: "#E1E7DA")]
        return palette[abs(entry.dayNumber) % palette.count]
    }

    private var galleryLabel: some View {
        Text("Open gallery")
            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
            .foregroundColor(JournalCardsUI.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.78))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(JournalCardsUI.border.opacity(0.35), lineWidth: JournalCardsUI.strokeWidth))
    }
}
