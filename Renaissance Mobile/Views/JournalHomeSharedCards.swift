//
//  JournalHomeSharedCards.swift
//  Renaissance Mobile
//

import SwiftUI

enum JournalCardsUI {
    static let primary   = Color(hex: "#6C63FF")
    static let ink       = Color(hex: "#2D2575")
    static let muted     = Color(hex: "#7B6FC0")
    static let pale      = Color(hex: "#A9A3D4")
    static let soft      = Color(hex: "#EAE7FF")
    static let line      = Color(hex: "#D4CCFF")
    static let shell     = Color(hex: "#F4F3FF")
    static let success   = Color(hex: "#5BBF84")
    static let pain      = Color(hex: "#E07373")
    static let swell     = Color(hex: "#6B9ECC")
    static let bruise    = Color(hex: "#7B70D4")
    static let redness   = Color(hex: "#C97070")
    // Semantic aliases used by JournalAlertCard
    static let roseSoft  = Color(hex: "#EAE7FF")
    static let textHi    = Color(hex: "#2D2575")
    static let textLo    = Color(hex: "#7B6FC0")
    static let cardWhite = Color.white
    static let border    = Color(hex: "#D4CCFF").opacity(0.55)
    static let shadowS = (
        color: Color(hex: "#6C63FF").opacity(0.06),
        radius: CGFloat(6),
        x: CGFloat(0),
        y: CGFloat(2)
    )
    static let cardRadius: CGFloat  = 22
    static let strokeWidth: CGFloat = 1
}

struct AllEntriesRoute: Hashable {}

// MARK: - Today Card

struct JournalTodayCard: View {
    var hasLoggedToday: Bool = false
    let latestEntry: JournalEntry?
    let procedureName: String?
    let onLogToday: () -> Void

    var body: some View {
        if hasLoggedToday {
            loggedCard
        } else {
            notLoggedCard
        }
    }

    private var notLoggedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's check-in")
                .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                .kerning(1.2)
                .foregroundColor(JournalCardsUI.muted)
                .textCase(.uppercase)

            Text("Ready to check in?")
                .font(.custom("Manrope", size: 20))
                .fontWeight(.bold)
                .foregroundColor(JournalCardsUI.ink)

            Button(action: onLogToday) {
                Text("Add today's entry")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(JournalCardsUI.primary)
                    .clipShape(Capsule())
                    .shadow(color: JournalCardsUI.primary.opacity(0.28), radius: 10, x: 0, y: 6)
            }
        }
        .padding(18)
        .background(JournalCardsUI.cardWhite)
        .cornerRadius(JournalCardsUI.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: JournalCardsUI.cardRadius)
                .stroke(JournalCardsUI.border, lineWidth: JournalCardsUI.strokeWidth)
        )
        .shadow(
            color: JournalCardsUI.shadowS.color,
            radius: JournalCardsUI.shadowS.radius,
            x: JournalCardsUI.shadowS.x,
            y: JournalCardsUI.shadowS.y
        )
    }

    private var loggedCard: some View {
        HStack(spacing: 14) {
            LottieView(name: "flower-growing", loop: true)
                .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(JournalCardsUI.success)
                    Text("Logged today")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                        .foregroundColor(JournalCardsUI.success)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(JournalCardsUI.success.opacity(0.12))
                .clipShape(Capsule())

                Text("You showed up for yourself today.")
                    .font(.custom("Manrope", size: 16))
                    .fontWeight(.bold)
                    .foregroundColor(JournalCardsUI.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Your recovery is being tracked.")
                    .font(.custom("PlusJakartaSans-Medium", size: 12))
                    .foregroundColor(JournalCardsUI.muted)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(hex: "#F0EEFF"), JournalCardsUI.soft],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(JournalCardsUI.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: JournalCardsUI.cardRadius)
                .stroke(JournalCardsUI.primary.opacity(0.2), lineWidth: JournalCardsUI.strokeWidth)
        )
        .shadow(
            color: JournalCardsUI.shadowS.color,
            radius: JournalCardsUI.shadowS.radius,
            x: JournalCardsUI.shadowS.x,
            y: JournalCardsUI.shadowS.y
        )
    }
}

// MARK: - Today Signals Card

struct JournalTodaySignalsCard: View {
    let pain: Int?
    let swelling: Int?
    let bruising: Int?
    var redness: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("How you felt")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                    .foregroundColor(JournalCardsUI.ink)

                Spacer()

                if let pain, pain > 0, pain <= 4 {
                    Text("Pain ↓ improving")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                        .foregroundColor(JournalCardsUI.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(JournalCardsUI.success.opacity(0.12))
                        .overlay(Capsule().stroke(JournalCardsUI.success.opacity(0.2), lineWidth: 1))
                        .clipShape(Capsule())
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                metricCell(icon: "⚡", name: "Pain",     value: pain,     color: JournalCardsUI.pain)
                metricCell(icon: "💧", name: "Swelling", value: swelling, color: JournalCardsUI.swell)
                metricCell(icon: "🟣", name: "Bruising", value: bruising, color: JournalCardsUI.bruise)
                metricCell(icon: "🌡️", name: "Redness",  value: redness,  color: JournalCardsUI.redness)
            }
        }
        .padding(16)
        .background(JournalCardsUI.cardWhite)
        .cornerRadius(JournalCardsUI.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: JournalCardsUI.cardRadius)
                .stroke(JournalCardsUI.border, lineWidth: JournalCardsUI.strokeWidth)
        )
        .shadow(
            color: JournalCardsUI.shadowS.color,
            radius: JournalCardsUI.shadowS.radius,
            x: JournalCardsUI.shadowS.x,
            y: JournalCardsUI.shadowS.y
        )
    }

    private func metricCell(icon: String, name: String, value: Int?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Text(icon)
                    .font(.system(size: 11))
                    .frame(width: 22, height: 22)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Text(name)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                    .foregroundColor(JournalCardsUI.ink)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(JournalCardsUI.pale.opacity(0.18))
                        .frame(height: 5)
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * CGFloat(value ?? 0) / 10.0, height: 5)
                }
            }
            .frame(height: 5)

            Text(value.map { metricLabel($0) } ?? "—")
                .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                .foregroundColor(value != nil ? color : JournalCardsUI.pale)
        }
        .padding(11)
        .background(JournalCardsUI.shell)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func metricLabel(_ v: Int) -> String {
        switch v {
        case 0:      return "0 · None"
        case 1...2:  return "\(v) · Very mild"
        case 3...4:  return "\(v) · Mild"
        case 5...6:  return "\(v) · Moderate"
        case 7...8:  return "\(v) · Significant"
        default:     return "\(v) · Severe"
        }
    }
}

// MARK: - Alert Card

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

// MARK: - Photo Reel Section

struct JournalPhotoReelSection: View {
    let entries: [JournalEntry]
    var onOpenGallery: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("Recent captures")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                    .foregroundColor(JournalCardsUI.ink)

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
                HStack(spacing: 10) {
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
        .padding(16)
        .background(JournalCardsUI.cardWhite)
        .cornerRadius(JournalCardsUI.cardRadius)
        .overlay(RoundedRectangle(cornerRadius: JournalCardsUI.cardRadius).stroke(JournalCardsUI.border, lineWidth: JournalCardsUI.strokeWidth))
        .shadow(
            color: JournalCardsUI.shadowS.color,
            radius: JournalCardsUI.shadowS.radius,
            x: JournalCardsUI.shadowS.x,
            y: JournalCardsUI.shadowS.y
        )
    }

    private func photoCard(entry: JournalEntry) -> some View {
        let today = Calendar.current.isDateInToday(entry.entryDateAsDate)
        return VStack(alignment: .center, spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(photoFill(for: entry))

                if let urlString = entry.photoUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(JournalCardsUI.muted.opacity(0.5))
                        default:
                            ProgressView()
                                .tint(JournalCardsUI.primary)
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(JournalCardsUI.muted.opacity(0.4))
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        today ? JournalCardsUI.primary : JournalCardsUI.line.opacity(0.5),
                        lineWidth: today ? 2 : 1.5
                    )
            )

            Text("Day \(entry.dayNumber)")
                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                .foregroundColor(JournalCardsUI.muted)

            Text(entry.entryDateAsDate.formatted(.dateTime.month(.abbreviated).day()))
                .font(.custom("PlusJakartaSans-Regular", size: 9))
                .foregroundColor(JournalCardsUI.pale)
        }
        .frame(width: 80)
    }

    private func placeholderPhotoCard(label: String) -> some View {
        VStack(alignment: .center, spacing: 5) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(JournalCardsUI.shell)
                .frame(width: 80, height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        .foregroundColor(JournalCardsUI.primary.opacity(0.35))
                )
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(JournalCardsUI.muted)
                )

            Text(label)
                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                .foregroundColor(JournalCardsUI.muted)

            Text("Add a photo")
                .font(.custom("PlusJakartaSans-Regular", size: 9))
                .foregroundColor(JournalCardsUI.pale)
        }
        .frame(width: 80)
    }

    private func photoFill(for entry: JournalEntry) -> Color {
        let palette: [Color] = [JournalCardsUI.shell, JournalCardsUI.soft, Color(hex: "#EDE8FF")]
        return palette[abs(entry.dayNumber) % palette.count]
    }

    private var galleryLabel: some View {
        Text("Open gallery")
            .font(.custom("PlusJakartaSans-SemiBold", size: 12))
            .foregroundColor(JournalCardsUI.primary)
    }
}
