//
//  WeekComparisonView.swift
//  Renaissance Mobile
//
//  Side-by-side photo comparison between two journal entries using an interactive
//  drag-divider slider. Launched from the "Compare" button in ProcedureEntriesView.
//

import SwiftUI

struct WeekComparisonView: View {
    let entries: [JournalEntry]

    @Environment(\.dismiss) private var dismiss

    @State private var leftEntry: JournalEntry?
    @State private var rightEntry: JournalEntry?
    @State private var leftImage: UIImage?
    @State private var rightImage: UIImage?
    @State private var sliderFraction: CGFloat = 0.5
    @State private var isDragging = false
    @State private var showLeftPicker = false
    @State private var showRightPicker = false
    @State private var isLoadingLeft = false
    @State private var isLoadingRight = false
    @State private var showComparisonChat = false

    private let primary = Color(hex: "#6C63FF")
    private let ink     = Color(hex: "#2D2575")
    private let muted   = Color(hex: "#7B6FC0")
    private let pale    = Color(hex: "#9C93C8")
    private let soft    = Color(hex: "#EAE7FF")
    private let line    = Color(hex: "#D4CCFF")
    private let bg      = Color(hex: "#F8F8FF")

    // Only entries that have photos are meaningful for visual comparison;
    // fall back to all entries so the picker always has options.
    private var photoEntries: [JournalEntry] {
        let withPhoto = entries.filter { $0.photoUrl != nil }
        return withPhoto.isEmpty ? entries : withPhoto
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                // Entry pickers
                pickerRow
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                // Comparison area
                if leftEntry != nil || rightEntry != nil {
                    comparisonArea
                        .padding(.horizontal, 18)

                    // Stats row
                    if leftEntry != nil || rightEntry != nil {
                        statsRow
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                    }

                    // Ask Rena — only when both entries are selected
                    if let left = leftEntry, let right = rightEntry {
                        askRenaButton(left: left, right: right)
                            .padding(.horizontal, 18)
                            .padding(.top, 16)
                    }
                } else {
                    emptyState
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showComparisonChat) {
            if let left = leftEntry, let right = rightEntry {
                ComparisonChatSheet(
                    leftEntry: left,
                    rightEntry: right,
                    leftImage: leftImage,
                    rightImage: rightImage
                )
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        ZStack {
            Text("Recovery Compare")
                .font(.custom("PlusJakartaSans-SemiBold", size: 18))
                .foregroundColor(ink)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ink)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.85))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(line.opacity(0.5), lineWidth: 1))
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 24)
        .padding(.bottom, 4)
    }

    // MARK: - Picker Row

    private var pickerRow: some View {
        HStack(spacing: 12) {
            entryPickerButton(
                label: leftEntry.map { entryLabel($0) } ?? "Before",
                placeholder: leftEntry == nil,
                isLoading: isLoadingLeft,
                action: { showLeftPicker = true }
            )

            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(pale)

            entryPickerButton(
                label: rightEntry.map { entryLabel($0) } ?? "After",
                placeholder: rightEntry == nil,
                isLoading: isLoadingRight,
                action: { showRightPicker = true }
            )
        }
        .confirmationDialog("Select 'Before' Entry", isPresented: $showLeftPicker, titleVisibility: .visible) {
            ForEach(photoEntries) { entry in
                Button(entryLabel(entry)) {
                    leftEntry = entry
                    leftImage = nil
                    Task { await loadImage(for: entry, side: .left) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Select 'After' Entry", isPresented: $showRightPicker, titleVisibility: .visible) {
            ForEach(photoEntries) { entry in
                Button(entryLabel(entry)) {
                    rightEntry = entry
                    rightImage = nil
                    Task { await loadImage(for: entry, side: .right) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func entryPickerButton(label: String, placeholder: Bool, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView().scaleEffect(0.8).tint(primary)
                } else {
                    Image(systemName: placeholder ? "plus.circle" : "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(placeholder ? pale : primary)
                }
                Text(label)
                    .font(.custom(placeholder ? "PlusJakartaSans-Regular" : "PlusJakartaSans-SemiBold", size: 13))
                    .foregroundColor(placeholder ? pale : ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(pale)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                placeholder ? line.opacity(0.5) : primary.opacity(0.25),
                lineWidth: 1
            ))
            .shadow(color: primary.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Comparison Area

    @ViewBuilder
    private var comparisonArea: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack(alignment: .leading) {
                // Right (after) image — full width base layer
                photoOrPlaceholder(image: rightImage, isLoading: isLoadingRight, label: "After")
                    .frame(width: width, height: height)
                    .clipped()

                // Left (before) image — clipped to slider position
                photoOrPlaceholder(image: leftImage, isLoading: isLoadingLeft, label: "Before")
                    .frame(width: width, height: height)
                    .frame(width: width * sliderFraction, alignment: .leading)
                    .clipped()

                // Divider line
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: height)
                    .offset(x: width * sliderFraction - 1)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 0)

                // Drag handle
                dragHandle
                    .offset(x: width * sliderFraction - 20)
            }
            .cornerRadius(16)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        isDragging = true
                        sliderFraction = max(0.05, min(0.95, value.location.x / width))
                    }
                    .onEnded { _ in isDragging = false }
            )
        }
        .frame(height: 340)
        .shadow(color: primary.opacity(0.10), radius: 12, x: 0, y: 6)
    }

    @ViewBuilder
    private func photoOrPlaceholder(image: UIImage?, isLoading: Bool, label: String) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if isLoading {
            ZStack {
                soft
                ProgressView().tint(primary)
            }
        } else {
            ZStack {
                soft
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(pale.opacity(0.6))
                    Text(label)
                        .font(.custom("PlusJakartaSans-Regular", size: 12))
                        .foregroundColor(pale)
                }
            }
        }
    }

    private var dragHandle: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 40, height: 40)
                .shadow(color: primary.opacity(0.18), radius: 8, x: 0, y: 2)

            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 9, weight: .bold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(primary)
        }
        .frame(width: 40, height: 40)
        .scaleEffect(isDragging ? 1.12 : 1.0)
        .animation(.spring(duration: 0.2), value: isDragging)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            if let entry = leftEntry { entryStatCard(entry, tint: primary) }
            Spacer()
            if let entry = rightEntry { entryStatCard(entry, tint: muted) }
        }
    }

    private func entryStatCard(_ entry: JournalEntry, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.dayLabel)
                .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                .foregroundColor(tint)
            Text(shortDate(entry.entryDateAsDate))
                .font(.custom("PlusJakartaSans-Regular", size: 11))
                .foregroundColor(pale)
            if entry.hasRecoveryMetrics {
                HStack(spacing: 6) {
                    metricDot("S", value: entry.swellingInt, tint: tint)
                    metricDot("B", value: entry.bruisingInt, tint: tint)
                    metricDot("R", value: entry.rednessInt, tint: tint)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.18), lineWidth: 1))
        .shadow(color: primary.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func metricDot(_ letter: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 3) {
            Text(letter)
                .font(.custom("PlusJakartaSans-Regular", size: 9))
                .foregroundColor(pale)
            Text("\(value)")
                .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                .foregroundColor(tint)
        }
    }

    // MARK: - Ask Rena Button

    private func askRenaButton(left: JournalEntry, right: JournalEntry) -> some View {
        Button { showComparisonChat = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                Text("Ask Rena about this comparison")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                LinearGradient(
                    colors: [primary, Color(hex: "#8B83FF")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: primary.opacity(0.28), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Image(systemName: "photo.stack")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(pale.opacity(0.5))
            Text("Pick two entries above to compare your healing progress side by side.")
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundColor(pale)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 36)
        }
    }

    // MARK: - Image Loading

    private enum Side { case left, right }

    @MainActor
    private func loadImage(for entry: JournalEntry, side: Side) async {
        guard let urlString = entry.photoUrl, let url = URL(string: urlString) else { return }
        switch side {
        case .left:  isLoadingLeft  = true
        case .right: isLoadingRight = true
        }
        defer {
            switch side {
            case .left:  isLoadingLeft  = false
            case .right: isLoadingRight = false
            }
        }
        if let data = try? await URLSession.shared.data(from: url).0,
           let image = UIImage(data: data) {
            switch side {
            case .left:  leftImage  = image
            case .right: rightImage = image
            }
        }
    }

    // MARK: - Helpers

    private func entryLabel(_ entry: JournalEntry) -> String {
        "\(entry.dayLabel) · \(shortDate(entry.entryDateAsDate))"
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    WeekComparisonView(entries: [])
}
