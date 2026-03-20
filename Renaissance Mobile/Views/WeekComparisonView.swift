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

    private let gradA  = Color(hex: "#6B3346")
    private let gradB  = Color(hex: "#B76E79")
    private let accent = Color(hex: "#C4929A")
    private let textHi = Color(hex: "#3D2B2E")
    private let textLo = Color(hex: "#B8A9AB")
    private let bg     = Color(hex: "#FFF8F6")

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
                } else {
                    emptyState
                }

                Spacer()
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        ZStack {
            Text("Recovery Compare")
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundColor(textHi)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textHi)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.7))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(accent.opacity(0.2), lineWidth: 1))
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
                .foregroundColor(accent)

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
                    ProgressView().scaleEffect(0.8).tint(accent)
                } else {
                    Image(systemName: placeholder ? "plus.circle" : "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(placeholder ? accent : gradA)
                }
                Text(label)
                    .font(.custom(placeholder ? "Outfit-Regular" : "Outfit-SemiBold", size: 13))
                    .foregroundColor(placeholder ? textLo : textHi)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                placeholder ? accent.opacity(0.18) : gradB.opacity(0.3),
                lineWidth: 1
            ))
            .shadow(color: Color(hex: "#8E4C5C").opacity(0.06), radius: 6, x: 0, y: 2)
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

                // Labels
                labelPill("BEFORE", position: .leading, sliderFraction: sliderFraction, width: width)
                labelPill("AFTER",  position: .trailing, sliderFraction: sliderFraction, width: width)
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
        .shadow(color: Color(hex: "#8E4C5C").opacity(0.12), radius: 12, x: 0, y: 6)
    }

    @ViewBuilder
    private func photoOrPlaceholder(image: UIImage?, isLoading: Bool, label: String) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if isLoading {
            ZStack {
                Color(hex: "#F5E8EE")
                ProgressView().tint(accent)
            }
        } else {
            ZStack {
                Color(hex: "#F5E8EE")
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(accent.opacity(0.5))
                    Text(label)
                        .font(.custom("Outfit-Regular", size: 12))
                        .foregroundColor(textLo)
                }
            }
        }
    }

    private var dragHandle: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 2)

            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 9, weight: .bold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(gradA)
        }
        .offset(y: 0)
        .frame(width: 40, height: 40)
        .scaleEffect(isDragging ? 1.12 : 1.0)
        .animation(.spring(duration: 0.2), value: isDragging)
    }

    private func labelPill(_ text: String, position: HorizontalAlignment, sliderFraction: CGFloat, width: CGFloat) -> some View {
        let show = position == .leading ? sliderFraction > 0.15 : sliderFraction < 0.85
        return Text(text)
            .font(.custom("Outfit-SemiBold", size: 9))
            .kerning(0.8)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.30))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: position == .leading ? .leading : .trailing)
            .padding(position == .leading ? .leading : .trailing, 10)
            .padding(.top, 12)
            .opacity(show ? 1 : 0)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            if let entry = leftEntry { entryStatCard(entry, tint: gradA) }
            Spacer()
            if let entry = rightEntry { entryStatCard(entry, tint: gradB) }
        }
    }

    private func entryStatCard(_ entry: JournalEntry, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.dayLabel)
                .font(.custom("Outfit-SemiBold", size: 12))
                .foregroundColor(tint)
            Text(shortDate(entry.entryDateAsDate))
                .font(.custom("Outfit-Regular", size: 11))
                .foregroundColor(textLo)
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
    }

    private func metricDot(_ letter: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 3) {
            Text(letter)
                .font(.custom("Outfit-Regular", size: 9))
                .foregroundColor(textLo)
            Text("\(value)")
                .font(.custom("Outfit-SemiBold", size: 11))
                .foregroundColor(tint)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Image(systemName: "photo.stack")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(accent.opacity(0.4))
            Text("Pick two entries above to compare your healing progress side by side.")
                .font(.custom("Outfit-Regular", size: 14))
                .foregroundColor(textLo)
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
