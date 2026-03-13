//
//  PostLoginHomeView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI
import Combine

struct PostLoginHomeView: View {
    @State private var navigateToChat = false
    @State private var firstName: String = ""
    @State private var journalViewModel = JournalViewModel()
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var carouselIndex = 0

    var onNavigateToChat: ((String) -> Void)?
    var onNavigateToProcedures: (() -> Void)?
    var onNavigateToJournal: (() -> Void)?

    private let userProfileService = UserProfileService(supabase: supabase)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    askRenaCard
                    spacer(height: Theme.Spacing.sm)
                    heroSection
                    recoverySection
                    brandLogoSection
                }
                .padding(.bottom, 100) // Space for bottom tab bar
            }
            .background(Theme.Colors.backgroundHome)
            .navigationBarHidden(true)
            .task {
                await loadUserProfile()
                await journalViewModel.load()
            }
        }
    }

    // MARK: - Data Loading

    private func loadUserProfile() async {
        do {
            let profile = try await userProfileService.getUserProfile()
            if let fullName = profile.fullName, !fullName.isEmpty {
                firstName = fullName.components(separatedBy: " ").first ?? fullName
            }
        } catch {
            print("Failed to load user profile: \(error)")
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack(alignment: .top) {
            Text("Hello, \(firstName.isEmpty ? "there" : firstName)")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(Theme.Colors.textHomePrimary)

            Spacer()

            // Profile avatar
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Theme.Colors.primaryHome)
                )
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.xxl)
        .padding(.bottom, Theme.Spacing.lg)
    }

    private var askRenaCard: some View {
        Button {
            onNavigateToChat?("")
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Canvas { context, size in
                    let cx = size.width / 2
                    let cy = size.height / 2
                    var p = Path()
                    p.addEllipse(in: CGRect(x: cx - 10, y: cy - 10, width: 20, height: 20))
                    context.stroke(p, with: .color(Color(hex: "#8E4C5C").opacity(0.55)), lineWidth: 0.8)
                    p = Path()
                    p.addEllipse(in: CGRect(x: cx - 7, y: cy - 7, width: 14, height: 14))
                    context.stroke(p, with: .color(Color(hex: "#8E4C5C").opacity(0.45)), lineWidth: 0.7)
                    p = Path()
                    p.addEllipse(in: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8))
                    context.stroke(p, with: .color(Color(hex: "#3D2B2E").opacity(0.4)), lineWidth: 0.8)
                    p = Path()
                    p.move(to: CGPoint(x: cx, y: cy - 3.5))
                    p.addCurve(to: CGPoint(x: cx + 3.5, y: cy), control1: CGPoint(x: cx + 2.5, y: cy - 3.5), control2: CGPoint(x: cx + 3.5, y: cy - 1.5))
                    p.addCurve(to: CGPoint(x: cx, y: cy + 3.5), control1: CGPoint(x: cx + 3.5, y: cy + 1.5), control2: CGPoint(x: cx + 2.5, y: cy + 3.5))
                    context.stroke(p, with: .color(Color(hex: "#8E4C5C").opacity(0.45)), lineWidth: 0.7)
                    p = Path()
                    p.addEllipse(in: CGRect(x: cx - 1.2, y: cy - 1.2, width: 2.4, height: 2.4))
                    context.fill(p, with: .color(Color(hex: "#8E4C5C").opacity(0.55)))
                }
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask Rena")
                        .font(Theme.Typography.cardLabel)
                        .foregroundColor(Theme.Colors.textHomePrimary)
                    Text("How can I help you today?")
                        .font(Theme.Typography.cardSubtitle)
                        .foregroundColor(Theme.Colors.textHomeMuted)
                }

                Spacer()

                Image(systemName: "arrow.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.primaryHome)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(Color.white)
            .cornerRadius(Theme.CornerRadius.medium)
            .shadow(
                color: Theme.Shadow.card.color,
                radius: Theme.Shadow.card.radius,
                x: Theme.Shadow.card.x,
                y: Theme.Shadow.card.y
            )
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var heroSection: some View {
        HeroCardView(
            title: "Explore Procedures",
            subtitle: "Find the perfect treatment for you.",
            imageName: nil,
            showLaunchingBadge: true
        )
        .padding(.horizontal, Theme.Spacing.lg)
        .onTapGesture {
            onNavigateToProcedures?()
        }
    }

    // MARK: - Daily Reflection Section

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Daily Reflection")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(Color(hex: "#3D2B2E"))
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.xl)

            weekStrip
            entryCarousel
        }
    }

    private var weekStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(weekDays(), id: \.self) { day in
                    dayCellView(day)
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Color.white.opacity(0.55))
        .cornerRadius(Theme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private func dayCellView(_ date: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(date, inSameDayAs: selectedDay)
        let dayNum = cal.component(.day, from: date)
        let hasEntry = entryForDay(date) != nil

        return Button {
            selectedDay = date
        } label: {
            VStack(spacing: 6) {
                VStack(spacing: Theme.Spacing.xs) {
                    Text(date, format: .dateTime.weekday(.abbreviated))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? Theme.Colors.textHomePrimary : Color(hex: "#C4929A"))

                    Text("\(dayNum)")
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? Theme.Colors.textHomePrimary : Color(hex: "#C4929A"))

                    // Entry indicator dot inside cell (non-selected days only)
                    Circle()
                        .fill(hasEntry && !isSelected ? Theme.Colors.primaryHome : Color.clear)
                        .frame(width: 5, height: 5)
                }
                .frame(width: 52, height: 72)
                .background(isSelected ? Color(hex: "#F2D7DB") : Color.clear)
                .cornerRadius(Theme.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(Color(hex: "#C4929A").opacity(isSelected ? 0.25 : 0), lineWidth: 1)
                )

                // Selection dot below the cell
                Circle()
                    .fill(isSelected ? Theme.Colors.primaryHome : Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Entry Carousel

    private var entryCarousel: some View {
        let entry = entryForDay(selectedDay)
        return VStack(spacing: Theme.Spacing.sm) {
            TabView(selection: $carouselIndex) {
                photoCard(entry: entry).tag(0)
                insightsCard(entry: entry).tag(1)
                logEntryCard.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 180)

            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i == carouselIndex
                              ? Theme.Colors.primaryHome
                              : Color(hex: "#C4929A").opacity(0.3))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeInOut) {
                carouselIndex = (carouselIndex + 1) % 3
            }
        }
        .onChange(of: selectedDay) {
            carouselIndex = 0
        }
    }

    private func photoCard(entry: JournalEntry?) -> some View {
        Group {
            if let urlString = entry?.photoUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        photoPlaceholder
                    }
                }
            } else {
                photoPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .cornerRadius(Theme.CornerRadius.medium)
        .clipped()
    }

    private var photoPlaceholder: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "camera")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(Color(hex: "#C4929A").opacity(0.6))
            Text("No photo for this day")
                .font(Theme.Typography.cardSubtitle)
                .foregroundColor(Theme.Colors.textHomeMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private func insightsCard(entry: JournalEntry?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.primaryHome)
                Text("Rena Insights")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(Theme.Colors.primaryHome)
            }

            if let summary = entry?.summary, !summary.isEmpty {
                Text(summary)
                    .font(Theme.Typography.cardSubtitle)
                    .foregroundColor(Theme.Colors.textHomePrimary)
                    .lineLimit(5)
            } else {
                Text("Start an entry so we can help you track your progress, flag any concerns, and give you important reminders.")
                    .font(Theme.Typography.cardSubtitle)
                    .foregroundColor(Theme.Colors.textHomeMuted)
                    .lineLimit(5)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Gradients.insightsCard)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var logEntryCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Spacer()

            Text("Create an entry to reflect")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Colors.textHomePrimary)

            Text("Document your recovery journey, one day at a time.")
                .font(Theme.Typography.cardSubtitle)
                .foregroundColor(Theme.Colors.textHomeMuted)

            Spacer()

            Button {
                onNavigateToJournal?()
            } label: {
                Text("Log")
                    .font(Theme.Typography.cardLabel)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.Brand.charcoalRose)
                    .cornerRadius(Theme.CornerRadius.pill)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Color.white)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - Brand Logo

    private var brandLogoSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Stacked logo mark — matches brand kit: 3 concentric circles + arc + center dot
            Canvas { context, size in
                let cx = size.width / 2
                let cy = size.height / 2

                // Outer circle — Mauve Berry
                var p = Path()
                p.addEllipse(in: CGRect(x: cx - 32, y: cy - 32, width: 64, height: 64))
                context.stroke(p, with: .color(Color(hex: "#8E4C5C").opacity(0.55)), lineWidth: 1.2)

                // Middle circle — Mauve Berry
                p = Path()
                p.addEllipse(in: CGRect(x: cx - 23, y: cy - 23, width: 46, height: 46))
                context.stroke(p, with: .color(Color(hex: "#8E4C5C").opacity(0.45)), lineWidth: 1)

                // Inner circle — Charcoal Rose
                p = Path()
                p.addEllipse(in: CGRect(x: cx - 14, y: cy - 14, width: 28, height: 28))
                context.stroke(p, with: .color(Color(hex: "#3D2B2E").opacity(0.4)), lineWidth: 1.2)

                // Arc — right half of inner circle (matches brand kit SVG path)
                p = Path()
                p.move(to: CGPoint(x: cx, y: cy - 12))
                p.addCurve(
                    to: CGPoint(x: cx + 12, y: cy),
                    control1: CGPoint(x: cx + 8, y: cy - 12),
                    control2: CGPoint(x: cx + 12, y: cy - 6)
                )
                p.addCurve(
                    to: CGPoint(x: cx, y: cy + 12),
                    control1: CGPoint(x: cx + 12, y: cy + 6),
                    control2: CGPoint(x: cx + 8, y: cy + 12)
                )
                context.stroke(p, with: .color(Color(hex: "#8E4C5C").opacity(0.45)), lineWidth: 1)

                // Center dot — Mauve Berry
                p = Path()
                p.addEllipse(in: CGRect(x: cx - 3.5, y: cy - 3.5, width: 7, height: 7))
                context.fill(p, with: .color(Color(hex: "#8E4C5C").opacity(0.55)))
            }
            .frame(width: 68, height: 68)

            // Wordmark — colors match brand kit stacked variant
            VStack(spacing: 3) {
                Text("Rena Aesthetic")
                    .font(.system(size: 14, weight: .light, design: .serif))
                    .foregroundColor(Color(hex: "#3D2B2E").opacity(0.85))
                Text("LAB")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(5)
                    .foregroundColor(Color(hex: "#8E4C5C").opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.xl)
    }

    // MARK: - Calendar Helpers

    private func weekDays() -> [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (-3...3).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: today)
        }
    }

    private func entryForDay(_ date: Date) -> JournalEntry? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        return journalViewModel.entries.first { $0.entryDate == dateString }
    }

    // MARK: - Helper

    private func spacer(height: CGFloat) -> some View {
        Color.clear.frame(height: height)
    }
}

#Preview {
    PostLoginHomeView()
}
