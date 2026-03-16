//
//  PostLoginHomeView.swift
//  Renaissance Mobile
//

import SwiftUI

struct PostLoginHomeView: View {
    @State private var navigateToProcedures = false
    @State private var firstName: String = ""
    @State private var journalViewModel = JournalViewModel()
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())

    var onNavigateToChat: ((String) -> Void)?
    var onNavigateToJournal: (() -> Void)?

    private let userProfileService = UserProfileService(supabase: supabase)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    askRenaCard
                    heroSection
                    recoverySection
                    brandLogoSection
                }
                .padding(.bottom, 100)
            }
            .background(Color(hex: "#FFF8F6"))
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToProcedures) {
                ProceduresListView()
            }
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

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Good morning,")
                    .font(.custom("Outfit-Light", size: 11.5))
                    .foregroundColor(Color(hex: "#B8A9AB"))
                    .tracking(0.3)
                Text("Hello, \(firstName.isEmpty ? "there" : firstName)")
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .foregroundColor(Color(hex: "#3D2B2E"))
            }

            Spacer()

            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: "#C4929A"))
                )
                .overlay(Circle().stroke(Color(hex: "#C4929A").opacity(0.18), lineWidth: 1.5))
                .shadow(color: Color(hex: "#8E4C5C").opacity(0.07), radius: 7, x: 0, y: 2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 60)
        .padding(.bottom, 18)
    }

    // MARK: - Ask Rena

    private var askRenaCard: some View {
        Button {
            onNavigateToChat?("")
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#8E4C5C").opacity(0.10))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Canvas { context, size in
                            let cx = size.width / 2
                            let cy = size.height / 2
                            var p = Path()
                            p.addEllipse(in: CGRect(x: cx-9.5, y: cy-9.5, width: 19, height: 19))
                            context.stroke(p, with: .color(Color(hex: "#8E4C5C")), lineWidth: 1.2)
                            p = Path()
                            p.addEllipse(in: CGRect(x: cx-6.5, y: cy-6.5, width: 13, height: 13))
                            context.stroke(p, with: .color(Color(hex: "#8E4C5C")), lineWidth: 1.0)
                            p = Path()
                            p.addEllipse(in: CGRect(x: cx-3.5, y: cy-3.5, width: 7, height: 7))
                            context.stroke(p, with: .color(Color(hex: "#8E4C5C")), lineWidth: 1.2)
                            p = Path()
                            p.addEllipse(in: CGRect(x: cx-1.5, y: cy-1.5, width: 3, height: 3))
                            context.fill(p, with: .color(Color(hex: "#8E4C5C")))
                        }
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask Rena")
                        .font(.custom("Outfit-SemiBold", size: 13))
                        .foregroundColor(Color(hex: "#3D2B2E"))
                    Text("How can I help you today?")
                        .font(.custom("Outfit-Light", size: 11))
                        .foregroundColor(Color(hex: "#B8A9AB"))
                }

                Spacer()

                Circle()
                    .fill(Color(hex: "#8E4C5C").opacity(0.10))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "arrow.forward")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#8E4C5C"))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#C4929A").opacity(0.18), lineWidth: 1))
            .shadow(color: Color(hex: "#8E4C5C").opacity(0.07), radius: 7, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    // MARK: - Hero

    private var heroSection: some View {
        HeroCardView(
            title: "Explore\nProcedures",
            subtitle: "Find the perfect treatment for you.",
            imageName: nil
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
        .onTapGesture {
            navigateToProcedures = true
        }
    }

    // MARK: - Daily Reflection

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily Reflection")
                    .font(.custom("Outfit-SemiBold", size: 15))
                    .foregroundColor(Color(hex: "#3D2B2E"))
                Spacer()
                Text("View all")
                    .font(.custom("Outfit-SemiBold", size: 11))
                    .foregroundColor(Color(hex: "#C4929A"))
            }
            .padding(.horizontal, 18)

            calendarCard
            journalCardArea
        }
    }

    // MARK: - Calendar

    private var calendarCard: some View {
        HStack(spacing: 0) {
            ForEach(weekDays(), id: \.self) { day in
                dayCellView(day)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 13)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#C4929A").opacity(0.18), lineWidth: 1))
        .shadow(color: Color(hex: "#8E4C5C").opacity(0.07), radius: 7, x: 0, y: 2)
        .padding(.horizontal, 18)
    }

    private func dayCellView(_ date: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(date, inSameDayAs: selectedDay)
        let dayNum = cal.component(.day, from: date)

        return Button {
            selectedDay = date
        } label: {
            VStack(spacing: 6) {
                Text(date, format: .dateTime.weekday(.abbreviated))
                    .font(.custom("Outfit-Regular", size: 9.5))
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? Color(hex: "#8E4C5C") : Color(hex: "#B8A9AB"))

                Text("\(dayNum)")
                    .font(.custom("Outfit-Regular", size: 14))
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? .white : Color(hex: "#B8A9AB"))
                    .frame(width: 32, height: 32)
                    .background(isSelected ? Color(hex: "#C4929A") : Color.clear)
                    .cornerRadius(10)
                    .shadow(
                        color: isSelected ? Color(hex: "#C4929A").opacity(0.42) : Color.clear,
                        radius: 6, x: 0, y: 3
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Journal Cards

    private var journalCardArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: "#8E4C5C"))
                    .frame(width: 5, height: 5)
                Text("Today")
                    .font(.custom("Outfit-SemiBold", size: 9.5))
                    .foregroundColor(Color(hex: "#8E4C5C"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(hex: "#8E4C5C").opacity(0.12))
            .clipShape(Capsule())
            .padding(.bottom, 9)

            Text("Create an entry to reflect")
                .font(.custom("Outfit-SemiBold", size: 13))
                .foregroundColor(Color(hex: "#3D2B2E"))
                .padding(.bottom, 4)

            Text("Document your recovery journey, one day at a time.")
                .font(.custom("Outfit-Light", size: 10.5))
                .foregroundColor(Color(hex: "#B8A9AB"))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button {
                onNavigateToJournal?()
            } label: {
                Text("Log Entry")
                    .font(.custom("Outfit-SemiBold", size: 12.5))
                    .tracking(0.4)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#8E4C5C"))
                    .cornerRadius(11)
                    .shadow(color: Color(hex: "#8E4C5C").opacity(0.28), radius: 7, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 172)
        .background(
            LinearGradient(
                colors: [Color(hex: "#f8e9ef"), Color(hex: "#f0d4dc")],
                startPoint: UnitPoint(x: 0, y: 0.15),
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color(hex: "#8E4C5C").opacity(0.12), radius: 12, x: 0, y: 5)
        .padding(.horizontal, 18)
    }

    // MARK: - Brand Logo

    private var brandLogoSection: some View {
        VStack(spacing: 8) {
            Canvas { context, size in
                let cx = size.width / 2
                let cy = size.height / 2
                var p = Path()
                p.addEllipse(in: CGRect(x: cx - 32, y: cy - 32, width: 64, height: 64))
                context.stroke(p, with: .color(Color(hex: "#8E4C5C").opacity(0.55)), lineWidth: 1.2)
                p = Path()
                p.addEllipse(in: CGRect(x: cx - 23, y: cy - 23, width: 46, height: 46))
                context.stroke(p, with: .color(Color(hex: "#8E4C5C").opacity(0.45)), lineWidth: 1)
                p = Path()
                p.addEllipse(in: CGRect(x: cx - 14, y: cy - 14, width: 28, height: 28))
                context.stroke(p, with: .color(Color(hex: "#3D2B2E").opacity(0.4)), lineWidth: 1.2)
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
                p = Path()
                p.addEllipse(in: CGRect(x: cx - 3.5, y: cy - 3.5, width: 7, height: 7))
                context.fill(p, with: .color(Color(hex: "#8E4C5C").opacity(0.55)))
            }
            .frame(width: 68, height: 68)

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
        .padding(.top, 24)
    }

    // MARK: - Helpers

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
}

#Preview {
    PostLoginHomeView()
}
