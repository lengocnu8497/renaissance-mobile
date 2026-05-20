//
//  ProcedureEntriesView.swift
//  Renaissance Mobile
//

import SwiftUI

struct ProcedureEntriesView: View {
    let procedureName: String?
    let vm: JournalViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var entryToDelete: JournalEntry?
    @State private var shareItems: [Any]?
    @State private var isPreparingShareFor: UUID?
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var showComparison = false
    @FocusState private var searchFocused: Bool

    private var entries: [JournalEntry] {
        vm.entries
            .filter { procedureName == nil || $0.procedureName == procedureName }
            .sorted { $0.entryDateAsDate > $1.entryDateAsDate }
    }

    private var filteredEntries: [JournalEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter {
            ($0.notes ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            if showSearch {
                searchBar
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: showSearch)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    entryContent
                    Color.clear.frame(height: 40)
                }
            }
        }
        .background(Color(hex: "#EEEEFF").ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showComparison) {
            WeekComparisonView(entries: entries)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems {
                ActivityViewController(items: items).ignoresSafeArea()
            }
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(get: { entryToDelete != nil }, set: { if !$0 { entryToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let entry = entryToDelete else { return }
                entryToDelete = nil
                Task { await vm.deleteEntry(entry) }
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        } message: {
            Text("This will permanently delete the photo and all data for this entry.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Button { dismiss() } label: {
                Circle()
                    .fill(Color.white)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#2D2575"))
                    )
                    .shadow(color: Color(hex: "#6C63FF").opacity(0.12), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("All Entries")
                .font(.custom("PlusJakartaSans-SemiBold", size: 20))
                .foregroundColor(Color(hex: "#2D2575"))

            Spacer()

            HStack(spacing: 8) {
                if let name = procedureName {
                    Button { vm.tapAddEntry(for: name) } label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 38, height: 38)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "#2D2575"))
                            )
                            .shadow(color: Color(hex: "#6C63FF").opacity(0.12), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }

                if entries.count >= 2 {
                    Button { showComparison = true } label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 38, height: 38)
                            .overlay(
                                Image(systemName: "square.2.layers.3d.top.filled")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(hex: "#6C63FF"))
                            )
                            .shadow(color: Color(hex: "#6C63FF").opacity(0.12), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearch.toggle()
                    }
                    if showSearch {
                        searchFocused = true
                    } else {
                        searchText = ""
                        searchFocused = false
                    }
                } label: {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                                .font(.system(size: 14, weight: showSearch ? .medium : .semibold))
                                .foregroundColor(Color(hex: "#2D2575"))
                        )
                        .shadow(color: Color(hex: "#6C63FF").opacity(0.12), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 56)
        .padding(.bottom, 16)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#9C93C8"))
            TextField("Search entries…", text: $searchText)
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundColor(Color(hex: "#2D2575"))
                .focused($searchFocused)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#D4CCFF"), lineWidth: 1))
        .shadow(color: Color(hex: "#6C63FF").opacity(0.08), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    // MARK: - Entry Content

    @ViewBuilder
    private var entryContent: some View {
        if filteredEntries.isEmpty {
            VStack(spacing: 8) {
                Spacer().frame(height: 60)
                Text(searchText.isEmpty ? "No entries yet." : "No results for \"\(searchText)\".")
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .foregroundColor(Color(hex: "#9C93C8"))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
        } else if searchText.isEmpty {
            sectionLabel("Recent")
            featuredCard(entry: filteredEntries[0])
                .padding(.horizontal, 18)

            let rest = Array(filteredEntries.dropFirst())
            if !rest.isEmpty {
                ForEach(groupedEntries(rest), id: \.label) { section in
                    sectionLabel(section.label)
                    VStack(spacing: 10) {
                        ForEach(section.entries) { entry in
                            compactCard(entry: entry)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        } else {
            ForEach(groupedEntries(filteredEntries), id: \.label) { section in
                sectionLabel(section.label)
                VStack(spacing: 10) {
                    ForEach(section.entries) { entry in
                        compactCard(entry: entry)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
            .tracking(1.4)
            .foregroundColor(Color(hex: "#9C93C8"))
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 10)
    }

    // MARK: - Featured Card

    private func featuredCard(entry: JournalEntry) -> some View {
        NavigationLink(value: entry.id) {
            VStack(alignment: .leading, spacing: 0) {
                if entry.photoUrl != nil {
                    photoContent(for: entry)
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(10)
                        .padding(.bottom, 14)
                }

                HStack(spacing: 6) {
                    Text(shortDate(entry.entryDateAsDate))
                        .font(.custom("PlusJakartaSans-Medium", size: 11))
                        .foregroundColor(Color(hex: "#6C63FF"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#EAE7FF"))
                        .clipShape(Capsule())

                    Text(procedureName ?? entry.procedureName)
                        .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                        .foregroundColor(Color(hex: "#6C63FF"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#EAE7FF"))
                        .clipShape(Capsule())

                    Spacer()
                }
                .padding(.bottom, 10)

                Text(titleFor(entry))
                    .font(.custom("PlusJakartaSans-SemiBold", size: 17))
                    .foregroundColor(Color(hex: "#2D2575"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 6)

                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundColor(Color(hex: "#7B6FC0"))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#E8E4FF"))
            .cornerRadius(16)
            .shadow(color: Color(hex: "#6C63FF").opacity(0.10), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { Task { await shareEntry(entry) } } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) { entryToDelete = entry } label: {
                Label("Delete Entry", systemImage: "trash")
            }
        }
    }

    // MARK: - Compact Card

    private func compactCard(entry: JournalEntry) -> some View {
        NavigationLink(value: entry.id) {
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 1) {
                    Text(entry.entryDateAsDate, format: .dateTime.weekday(.abbreviated))
                        .font(.custom("PlusJakartaSans-Regular", size: 10))
                        .foregroundColor(Color(hex: "#9C93C8"))
                    Text(entry.entryDateAsDate, format: .dateTime.day())
                        .font(.custom("PlusJakartaSans-SemiBold", size: 18))
                        .foregroundColor(Color(hex: "#2D2575"))
                }
                .frame(width: 36)

                Rectangle()
                    .fill(Color(hex: "#D4CCFF"))
                    .frame(width: 1)
                    .frame(minHeight: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(titleFor(entry))
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                        .foregroundColor(Color(hex: "#2D2575"))
                        .lineLimit(1)

                    if let sub = subtitleFor(entry) {
                        Text(sub)
                            .font(.custom("PlusJakartaSans-Regular", size: 12))
                            .foregroundColor(Color(hex: "#9C93C8"))
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)

                Circle()
                    .fill(Color(hex: "#EAE7FF"))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "arrow.forward")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#6C63FF"))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#E8E4FF"), lineWidth: 1))
            .shadow(color: Color(hex: "#6C63FF").opacity(0.06), radius: 7, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { Task { await shareEntry(entry) } } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) { entryToDelete = entry } label: {
                Label("Delete Entry", systemImage: "trash")
            }
        }
    }

    // MARK: - Grouping

    private struct EntrySection {
        let label: String
        let entries: [JournalEntry]
    }

    private func groupedEntries(_ list: [JournalEntry]) -> [EntrySection] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard
            let thisWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
            let lastWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)
        else {
            return [EntrySection(label: "Entries", entries: list)]
        }

        let monthFmt = DateFormatter()
        monthFmt.dateFormat = "MMMM yyyy"

        var labelOrder: [String] = []
        var grouped: [String: [JournalEntry]] = [:]

        for entry in list {
            let d = cal.startOfDay(for: entry.entryDateAsDate)
            let label: String
            if d >= thisWeekStart {
                label = "This Week"
            } else if d >= lastWeekStart {
                label = "Last Week"
            } else {
                label = monthFmt.string(from: d)
            }
            if grouped[label] == nil {
                labelOrder.append(label)
                grouped[label] = []
            }
            grouped[label]!.append(entry)
        }

        return labelOrder.map { EntrySection(label: $0, entries: grouped[$0]!) }
    }

    // MARK: - Text Helpers

    private func titleFor(_ entry: JournalEntry) -> String {
        guard let notes = entry.notes, !notes.isEmpty else { return "Day \(entry.dayNumber)" }
        let first = notes.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces) ?? ""
        return first.isEmpty ? "Day \(entry.dayNumber)" : first
    }

    private func subtitleFor(_ entry: JournalEntry) -> String? {
        guard let notes = entry.notes, !notes.isEmpty else { return nil }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let title = titleFor(entry)
        // If title is the Day N fallback, show all notes as preview
        if title == "Day \(entry.dayNumber)" { return trimmed }
        // Title came from notes — show content after it to avoid repetition
        let rest = trimmed.hasPrefix(title)
            ? String(trimmed.dropFirst(title.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            : trimmed
        return rest.isEmpty ? nil : rest
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    // MARK: - Share

    @MainActor
    private func shareEntry(_ entry: JournalEntry) async {
        guard isPreparingShareFor == nil else { return }
        isPreparingShareFor = entry.id
        defer { isPreparingShareFor = nil }

        var loadedPhoto: UIImage?
        if let urlString = entry.photoUrl, let url = URL(string: urlString) {
            let data = try? await URLSession.shared.data(from: url).0
            loadedPhoto = data.flatMap { UIImage(data: $0) }
        }

        let card = ShareableEntryCard(entry: entry, photo: loadedPhoto)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        renderer.proposedSize = .init(width: 375, height: 470)

        guard let image = renderer.uiImage else { return }
        shareItems = [image, ShareableEntryCard.caption(for: entry)]
    }

    // MARK: - Photo Helpers

    @ViewBuilder
    private func photoContent(for entry: JournalEntry) -> some View {
        if let urlString = entry.photoUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color(hex: "#EAE7FF")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color(hex: "#EAE7FF")
        }
    }
}
