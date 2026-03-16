//
//  PhotoJournalView.swift
//  Renaissance Mobile
//

import SwiftUI

// MARK: - Design tokens — sourced directly from rena-journal-ai-insights.html

private enum J {
    static let pageBg        = Color(hex: "#FFF8F6")
    static let primary       = Color(hex: "#8E4C5C")   // Mauve Berry – positive / progress
    static let gradA         = Color(hex: "#6B3346")   // Hero gradient dark end
    static let gradMid       = Color(hex: "#8E4C5C")   // Hero gradient mid stop (52%)
    static let gradB         = Color(hex: "#B76E79")   // Rose Gold – concern / flag
    static let accent        = Color(hex: "#C4929A")   // Dusty Rose – reminder / calendar active
    static let textHi        = Color(hex: "#3D2B2E")
    static let textLo        = Color(hex: "#B8A9AB")
    static let cardWhite     = Color.white
    static let border        = Color(hex: "#C4929A").opacity(0.18)
    // AI card tints
    static let concernTint   = Color(hex: "#FEF0F2")
    static let reminderTint  = Color(hex: "#FDF5F6")
    static let positiveTint  = Color(hex: "#F8EDF0")
    // Dimmed primary (badges, arrow buttons)
    static let primaryDim    = Color(hex: "#8E4C5C").opacity(0.10)
    // Shadows  (blur values in HTML → SwiftUI radius ≈ blur/2)
    static let shadowS       = (color: Color(hex: "#8E4C5C").opacity(0.07), radius: CGFloat(7),  x: CGFloat(0), y: CGFloat(2))
    static let shadowHero    = (color: Color(hex: "#6B3346").opacity(0.30), radius: CGFloat(14), x: CGFloat(0), y: CGFloat(8))
}

struct PhotoJournalView: View {
    var addEntryTrigger: Binding<Bool> = .constant(false)

    @Environment(\.dismiss) private var dismiss
    @State private var vm = JournalViewModel()
    @State private var groupToDelete: (key: String, entries: [JournalEntry])?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection

                if vm.isLoading && vm.entries.isEmpty {
                    Spacer()
                    ProgressView().tint(J.accent)
                    Spacer()
                } else {
                    mainContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(J.pageBg.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { procedureName in
                ProcedureEntriesView(procedureName: procedureName, vm: vm)
            }
            .sheet(isPresented: $vm.showAddEntry, onDismiss: { vm.pendingProcedureName = nil }) {
                AddJournalEntryView(
                    existingEntries: vm.entries,
                    prefilledProcedureName: vm.pendingProcedureName
                ) { procedureId, procedureName, dayNumber, entryDate, notes, photoData in
                    return await vm.addEntry(
                        procedureId: procedureId,
                        procedureName: procedureName,
                        dayNumber: dayNumber,
                        entryDate: entryDate,
                        notes: notes,
                        photoData: photoData
                    )
                }
            }
            .alert("Couldn't Save Entry", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) {
                Button("OK", role: .cancel) { vm.error = nil }
            } message: {
                Text(vm.error ?? "")
            }
            .overlay(alignment: .bottom) {
                if vm.showConsentBanner {
                    PhotoConsentBannerView(
                        onGrant: { vm.grantConsent() },
                        onDeny:  { vm.denyConsent() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(duration: 0.35), value: vm.showConsentBanner)
                }
            }
        }
        .task { await vm.load() }
        .onChange(of: addEntryTrigger.wrappedValue) { _, triggered in
            if triggered {
                vm.tapAddEntry()
                addEntryTrigger.wrappedValue = false
            }
        }
        .alert(
            "Delete \"\(groupToDelete?.key ?? "")\"?",
            isPresented: Binding(get: { groupToDelete != nil }, set: { if !$0 { groupToDelete = nil } })
        ) {
            Button("Delete All Entries", role: .destructive) {
                guard let group = groupToDelete,
                      let procedureId = group.entries.first?.procedureId else { return }
                groupToDelete = nil
                Task { await vm.deleteProcedureGroup(procedureId: procedureId) }
            }
            Button("Cancel", role: .cancel) { groupToDelete = nil }
        } message: {
            let count = groupToDelete?.entries.count ?? 0
            Text("This will permanently delete all \(count) \(count == 1 ? "entry" : "entries") in this group.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack {
            // Centered title
            Text("My Journal")
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundColor(J.textHi)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                // Back button — chevron in circle (matches HTML .back-btn)
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(J.textHi)
                        .frame(width: 36, height: 36)
                        .background(J.cardWhite)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(J.border, lineWidth: 1))
                        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
                }

                Spacer()

                // Empty spacer to balance the back button and keep title centered
                Color.clear.frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 52)
        .padding(.bottom, 14)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {

                // 1. Recovery Hero Card
                JournalHeroCard(
                    heroData: vm.heroData,
                    streak: vm.streak,
                    isNewUser: !vm.hasEverLoggedEntry
                )
                .padding(.horizontal, 18)

                // 2. Rena Insights Section
                JournalInsightsSection(
                    insights: vm.primaryInsights,
                    isGenerating: vm.isPrimaryGenerating,
                    isEmpty: vm.entries.isEmpty
                )

                // 3. Calendar Strip
                JournalCalendarStrip(
                    weekDates: vm.currentWeekDates,
                    entryDates: Set(vm.entries.map(\.entryDate)),
                    onDateTap: { date in
                        let key = isoDate(date)
                        // Past/today date with no entry → open add entry sheet
                        if !vm.entries.contains(where: { $0.entryDate == key }) {
                            vm.tapAddEntry()
                        }
                    }
                )
                .padding(.horizontal, 18)

                // 4. Entries or empty CTA
                if vm.entries.isEmpty {
                    emptyEntriesSection
                        .padding(.horizontal, 18)
                } else {
                    recentEntriesSection
                }

                Color.clear.frame(height: 40)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Empty Entries Section

    private var emptyEntriesSection: some View {
        let isNewUser = !vm.hasEverLoggedEntry
        return VStack(spacing: 16) {
            Text("✦")
                .font(.system(size: 24))
                .foregroundColor(J.accent.opacity(0.45))

            VStack(spacing: 6) {
                Text(isNewUser ? "Your story starts here." : "Welcome back.")
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundColor(J.textHi)
                    .multilineTextAlignment(.center)

                Text(
                    isNewUser
                        ? "Log your first entry to begin tracking your recovery journey."
                        : "Ready to continue your story? Log an entry to keep your journey going."
                )
                .font(.custom("Outfit-Light", size: 13))
                .foregroundColor(J.textLo)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            }

            // Primary CTA
            Button { vm.tapAddEntry() } label: {
                Text(isNewUser ? "Begin Your Journey" : "Add Entry")
                    .font(.custom("Outfit-SemiBold", size: 14))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(J.primary)
                    .cornerRadius(100)
            }

            // Secondary CTA
            Button { } label: {
                Text(isNewUser ? "Explore sample insights" : "Learn how it works")
                    .font(.custom("Outfit-Regular", size: 13))
                    .foregroundColor(J.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .background(J.cardWhite)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(J.border, lineWidth: 1))
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
    }

    // MARK: - Recent Entries Section

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Recent Entries")
                    .font(.custom("Outfit-SemiBold", size: 13))
                    .foregroundColor(J.textHi)
                Spacer()
                Text("See all")
                    .font(.custom("Outfit-Regular", size: 11))
                    .foregroundColor(J.accent)
            }
            .padding(.horizontal, 18)

            VStack(spacing: 7) {
                ForEach(sortedEntries) { entry in
                    NavigationLink(value: entry.procedureName) {
                        CompactEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { deleteGroupButton(for: entry) }
                }
            }
            .padding(.horizontal, 18)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func deleteGroupButton(for entry: JournalEntry) -> some View {
        Button(role: .destructive) {
            if let group = vm.groupedByProcedure.first(where: { $0.key == entry.procedureName }) {
                groupToDelete = group
            }
        } label: {
            Label("Delete Group", systemImage: "trash")
        }
    }

    private var sortedEntries: [JournalEntry] {
        vm.entries.sorted { $0.entryDateAsDate > $1.entryDateAsDate }
    }

    private func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Recovery Hero Card

private struct JournalHeroCard: View {
    let heroData: (procedureName: String, dayNumber: Int, progress: Double)?
    let streak: Int
    let isNewUser: Bool

    var body: some View {
        ZStack {
            // 1. Background gradient: 130deg, #6B3346 → #8E4C5C → #B76E79
            LinearGradient(
                stops: [
                    .init(color: J.gradA,   location: 0.00),
                    .init(color: J.gradMid, location: 0.52),
                    .init(color: J.gradB,   location: 1.00)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 2. Decorative circle rings (bottom-right, partially clipped)
            GeometryReader { geo in
                // Outer ring: 170×170, center at (width-45, height-35)
                Circle()
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
                    .frame(width: 170, height: 170)
                    .position(x: geo.size.width - 45, y: geo.size.height - 35)

                // Inner ring: 110×110, center at (width-65, height-45)
                Circle()
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
                    .frame(width: 110, height: 110)
                    .position(x: geo.size.width - 65, y: geo.size.height - 45)
            }

            // 3. Card content
            HStack(alignment: .top, spacing: 0) {
                // Left column: eyebrow, day number, label, progress
                VStack(alignment: .leading, spacing: 0) {
                    Text("RECOVERY JOURNEY")
                        .font(.custom("Outfit-Regular", size: 9))
                        .kerning(3)
                        .foregroundColor(.white.opacity(0.55))

                    Spacer().frame(height: 3)

                    Text(heroData != nil ? "\(heroData!.dayNumber)" : "0")
                        .font(.system(size: 40, weight: .light, design: .serif))
                        .foregroundColor(heroData != nil ? .white : .white.opacity(0.3))

                    Text(
                        heroData != nil
                            ? "days of recovery"
                            : (isNewUser ? "your journey begins today" : "welcome back")
                    )
                    .font(.custom("Outfit-Light", size: 10))
                    .foregroundColor(heroData != nil ? .white.opacity(0.65) : .white.opacity(0.35))
                    .lineLimit(1)

                    Spacer().frame(height: 10)

                    progressBar(progress: heroData?.progress ?? 0)
                }

                Spacer()

                // Right column: streak badge
                if streak > 0 {
                    Text("🔥 \(streak)-day streak")
                        .font(.custom("Outfit-SemiBold", size: 9))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.16))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(16)
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(
            color: J.shadowHero.color,
            radius: J.shadowHero.radius,
            x: J.shadowHero.x,
            y: J.shadowHero.y
        )
    }

    private func progressBar(progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 100)
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 3)
                    // Fill: white opacity gradient (matches HTML)
                    RoundedRectangle(cornerRadius: 100)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.6), Color.white.opacity(0.95)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * 0.8 * max(progress, 0), height: 3)
                        .animation(.easeOut(duration: 0.8), value: progress)
                }
            }
            .frame(width: nil, height: 3)
            // Constrain to ~80% width like the HTML
            .frame(maxWidth: .infinity)
            .padding(.trailing, 40)

            Text(
                heroData != nil
                    ? "\(Int(progress * 100))% of 28-day plan"
                    : "start logging to track progress"
            )
            .font(.custom("Outfit-Regular", size: 9))
            .foregroundColor(.white.opacity(0.48))
        }
    }
}

// MARK: - Rena Insights Section

private struct JournalInsightsSection: View {
    let insights: RecoveryInsights?
    let isGenerating: Bool
    let isEmpty: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            // Section header
            HStack(spacing: 7) {
                // Rena AI logo mark: 22×22 rounded square, gradient, concentric circles
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        LinearGradient(
                            colors: [J.gradA, J.gradMid, J.gradB],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                    .overlay(concentricCirclesIcon)

                Text("Rena Insights")
                    .font(.custom("Outfit-SemiBold", size: 13))
                    .foregroundColor(J.textHi)

                if !isEmpty, insights != nil {
                    Text("3 new")
                        .font(.custom("Outfit-Bold", size: 9.5))
                        .foregroundColor(J.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(J.primaryDim)
                        .clipShape(Capsule())
                }

                Spacer()

                if !isEmpty {
                    Text("See all")
                        .font(.custom("Outfit-Regular", size: 11))
                        .foregroundColor(J.accent)
                }
            }
            .padding(.horizontal, 18)

            // Horizontal card carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    if isEmpty {
                        InsightCard(type: .placeholder, message: "Log your first entry to unlock AI-powered recovery insights.")
                    } else if isGenerating && insights == nil {
                        InsightCard(type: .generating, message: "Analyzing your recovery journey…")
                    } else if let insights {
                        InsightCard(type: .progress, message: insights.summary)
                        ForEach(Array(insights.flags.prefix(2).enumerated()), id: \.offset) { _, flag in
                            InsightCard(
                                type: flag.severity == .urgent ? .concern : .reminder,
                                message: flag.message
                            )
                        }
                        if let encouragement = insights.encouragements.first {
                            InsightCard(type: .progress, message: encouragement)
                        }
                    } else {
                        InsightCard(type: .placeholder, message: "Keep logging entries to unlock AI-powered recovery insights.")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 2)
            }

            // Scroll position dots
            HStack(spacing: 5) {
                Capsule()
                    .fill(J.primary)
                    .frame(width: 14, height: 5)
                ForEach(0..<2, id: \.self) { _ in
                    Circle()
                        .fill(J.border)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var concentricCirclesIcon: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 0.8)
                .frame(width: 11, height: 11)
            Circle()
                .stroke(Color.white.opacity(0.8), lineWidth: 0.8)
                .frame(width: 7.2, height: 7.2)
            Circle()
                .stroke(Color.white, lineWidth: 0.8)
                .frame(width: 3.4, height: 3.4)
            Circle()
                .fill(Color.white)
                .frame(width: 1.5, height: 1.5)
        }
    }
}

// MARK: - Insight Card

private enum InsightCardType {
    case concern, reminder, progress, placeholder, generating

    var accentColor: Color {
        switch self {
        case .concern:              return J.gradB     // Rose Gold #B76E79
        case .reminder:             return J.accent    // Dusty Rose #C4929A
        case .progress:             return J.primary   // Mauve Berry #8E4C5C
        case .placeholder, .generating: return J.accent
        }
    }
    var tintBackground: Color {
        switch self {
        case .concern:              return J.concernTint   // #FEF0F2
        case .reminder:             return J.reminderTint  // #FDF5F6
        case .progress:             return J.positiveTint  // #F8EDF0
        case .placeholder, .generating: return Color(hex: "#FDF5F6")
        }
    }
    var borderColor: Color {
        switch self {
        case .concern:              return J.gradB.opacity(0.22)
        case .reminder:             return J.accent.opacity(0.22)
        case .progress:             return J.primary.opacity(0.18)
        case .placeholder, .generating: return J.accent.opacity(0.18)
        }
    }
    var icon: String {
        switch self {
        case .concern:   return "exclamationmark.triangle.fill"
        case .reminder:  return "bell.fill"
        case .progress:  return "star.fill"
        case .placeholder, .generating: return "sparkles"
        }
    }
    var typeLabel: String {
        switch self {
        case .concern:   return "CONCERN"
        case .reminder:  return "REMINDER"
        case .progress:  return "PROGRESS"
        case .placeholder: return "INSIGHTS"
        case .generating: return "ANALYZING"
        }
    }
    var ctaLabel: String {
        switch self {
        case .concern:   return "Talk to Rena"
        case .reminder:  return "Set reminder"
        case .progress:  return "View trends"
        case .placeholder, .generating: return ""
        }
    }
}

private struct InsightCard: View {
    let type: InsightCardType
    let message: String

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar — full card height via clipShape
            Rectangle()
                .fill(type.accentColor)
                .frame(width: 3.5)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Type header
                HStack(spacing: 6) {
                    // Icon in tinted square
                    RoundedRectangle(cornerRadius: 6)
                        .fill(type.accentColor.opacity(0.14))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: type.icon)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(type.accentColor)
                        )

                    Text(type.typeLabel)
                        .font(.custom("Outfit-Bold", size: 9))
                        .kerning(1.5)
                        .foregroundColor(type.accentColor)
                }

                // Body text
                Text(message)
                    .font(.custom("Outfit-Regular", size: 11.5))
                    .foregroundColor(J.textHi)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // CTA (hidden for placeholder/generating)
                if !type.ctaLabel.isEmpty {
                    HStack(spacing: 4) {
                        Text(type.ctaLabel)
                            .font(.custom("Outfit-SemiBold", size: 10.5))
                            .foregroundColor(type.accentColor)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(type.accentColor)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(type.tintBackground)
        }
        .frame(width: 218)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(type.borderColor, lineWidth: 1)
        )
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
    }
}

// MARK: - Calendar Strip

private struct JournalCalendarStrip: View {
    let weekDates: [Date]
    let entryDates: Set<String>
    var onDateTap: ((Date) -> Void)? = nil

    private static let dayNameFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()
    private static let entryKeyFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                dayCell(date: date)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(J.cardWhite)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(J.border, lineWidth: 1))
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
    }

    private func dayCell(date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()
        let dateKey = Self.entryKeyFormatter.string(from: date)
        let hasEntry = entryDates.contains(dateKey)
        let dayNum = calendar.component(.day, from: date)
        let dayName = String(Self.dayNameFormatter.string(from: date).prefix(3))
        let isTappable = !isFuture

        return VStack(alignment: .center, spacing: 5) {
            // Day name (e.g. "Mon")
            Text(dayName)
                .font(.custom("Outfit-Regular", size: 9))
                .foregroundColor(isToday ? J.primary : (isFuture ? J.textLo.opacity(0.4) : J.textLo))
                .fontWeight(isToday ? .semibold : .regular)

            // Day number — rounded square (borderRadius: 9) when active
            ZStack {
                if isToday {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(J.accent)
                        .frame(width: 30, height: 30)
                        .shadow(color: J.accent.opacity(0.4), radius: 5, x: 0, y: 3)
                } else if isTappable && hasEntry {
                    // Past day with entry — subtle filled background
                    RoundedRectangle(cornerRadius: 9)
                        .fill(J.accent.opacity(0.12))
                        .frame(width: 30, height: 30)
                }
                Text("\(dayNum)")
                    .font(.system(size: 13, weight: isToday ? .bold : .regular))
                    .foregroundColor(
                        isToday ? .white
                        : isFuture ? J.textLo.opacity(0.35)
                        : hasEntry ? J.primary
                        : J.textLo
                    )
            }
            .frame(width: 30, height: 30)

            // Entry dot
            Circle()
                .fill(hasEntry ? J.gradB : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isTappable else { return }
            onDateTap?(date)
        }
    }
}

// MARK: - Compact Entry Row

private struct CompactEntryRow: View {
    let entry: JournalEntry

    private static let entryKeyFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE · MMM d"; return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar (clips to card corners via clipShape below)
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)

            // Entry body
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.entryKeyFormatter.string(from: entry.entryDateAsDate) + " · " + entry.dayLabel)
                        .font(.custom("Outfit-Regular", size: 9))
                        .foregroundColor(J.textLo)

                    Text(entry.procedureName)
                        .font(.custom("Outfit-SemiBold", size: 12))
                        .foregroundColor(J.textHi)
                        .lineLimit(1)

                    if let notes = entry.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.custom("Outfit-Light", size: 10))
                            .foregroundColor(J.textLo)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Circular arrow button (#8E4C5C dimmed bg)
                ZStack {
                    Circle()
                        .fill(J.primaryDim)
                        .frame(width: 22, height: 22)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(J.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(J.cardWhite)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(J.border, lineWidth: 1))
        .shadow(color: J.shadowS.color, radius: J.shadowS.radius, x: J.shadowS.x, y: J.shadowS.y)
    }

    private var accentColor: Color {
        // Cycle accent bar through brand colors by procedure name hash
        let colors: [Color] = [J.gradB, J.primary, J.accent, Color(hex: "#D4C4C6")]
        return colors[abs(entry.procedureName.hashValue) % colors.count]
    }
}

#Preview {
    PhotoJournalView()
}
