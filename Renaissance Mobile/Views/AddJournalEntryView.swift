//
//  AddJournalEntryView.swift
//  Renaissance Mobile
//

import SwiftUI
import PhotosUI

struct AddJournalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    var existingEntries: [JournalEntry] = []
    var onSave: (String, String, Int, Date, String?, Data?) async -> Void

    // Navigation
    @State private var currentStep: Int
    @State private var goingForward = true
    private let startStep: Int
    private let totalSteps = 4

    // Procedure
    @State private var procedureName: String

    init(
        existingEntries: [JournalEntry] = [],
        prefilledProcedureName: String? = nil,
        onSave: @escaping (String, String, Int, Date, String?, Data?) async -> Void
    ) {
        self.existingEntries = existingEntries
        self.onSave = onSave
        let step = prefilledProcedureName != nil ? 1 : 0
        self.startStep = step
        _currentStep = State(initialValue: step)
        _procedureName = State(initialValue: prefilledProcedureName ?? "")
    }

    // Entry fields
    @State private var dayNumber = 0
    @State private var entryDate = Date()
    @State private var notes = ""

    // Photo
    @State private var capturedImage: UIImage?
    @State private var libraryItem: PhotosPickerItem?
    @State private var showCamera = false

    @State private var isSaving = false

    private var procedureId: String {
        procedureName
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }

    private var canAdvance: Bool {
        currentStep == 0
            ? !procedureName.trimmingCharacters(in: .whitespaces).isEmpty
            : true
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
    }()

    var body: some View {
        ZStack {
            Color(hex: "#C4929A").ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, Theme.Spacing.md)

                // Step content with slide transition
                ZStack {
                    switch currentStep {
                    case 0: procedureStep
                    case 1: dayStep
                    case 2: photoStep
                    default: notesStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(currentStep)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: goingForward ? .trailing : .leading),
                        removal: .move(edge: goingForward ? .leading : .trailing)
                    )
                )
                .animation(.easeInOut(duration: 0.28), value: currentStep)

                bottomNav
            }
        }
        .interactiveDismissDisabled(false)
        .fullScreenCover(isPresented: $showCamera) {
            PhotoCaptureView(capturedImage: $capturedImage)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Brand.charcoalRose.opacity(0.65))
                    .frame(width: 36, height: 36)
                    .background(Theme.Brand.charcoalRose.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            // Step progress pills
            HStack(spacing: 5) {
                ForEach(startStep..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= currentStep
                              ? Theme.Brand.charcoalRose
                              : Theme.Brand.charcoalRose.opacity(0.18))
                        .frame(width: i == currentStep ? 22 : 6, height: 6)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentStep)
                }
            }

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Step 1: Procedure

    private var procedureStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "What procedure\nare you tracking?",
                subtitle: Self.dateFormatter.string(from: Date())
            )

            Spacer()

            // Ghost placeholder + live input
            ZStack(alignment: .topLeading) {
                if procedureName.isEmpty {
                    Text("Rhinoplasty,\nLip filler…")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(Theme.Brand.charcoalRose.opacity(0.18))
                        .allowsHitTesting(false)
                }
                TextField("", text: $procedureName, axis: .vertical)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(Theme.Brand.charcoalRose)
                    .tint(Theme.Brand.charcoalRose)
                    .lineLimit(3)
                    .submitLabel(.done)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 2: Day

    private var dayStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "When is this\nentry for?",
                subtitle: procedureName
            )

            Spacer()

            VStack(spacing: Theme.Spacing.xl) {
                // Large day display (read-only)
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    if dayNumber == 0 {
                        Text("Day of\nprocedure")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Theme.Brand.charcoalRose)
                            .lineLimit(2)
                    } else {
                        Text("Day")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(Theme.Brand.charcoalRose.opacity(0.45))
                        Text("\(dayNumber)")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundColor(Theme.Brand.charcoalRose)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Auto-calculated from your journal start date")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Brand.charcoalRose.opacity(0.55))
                    .padding(.horizontal, Theme.Spacing.xl)

                // Date picker
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Brand.charcoalRose.opacity(0.6))
                    DatePicker("", selection: $entryDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Theme.Brand.charcoalRose)
                        .colorScheme(.light)
                        .onChange(of: entryDate) { _, _ in recalculateDayNumber() }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.sm)
            }

            Spacer()
            Spacer()
        }
        .onAppear { recalculateDayNumber() }
    }

    // MARK: - Step 3: Photo

    private var photoStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "Add a photo\n(optional)",
                subtitle: "Day \(dayNumber) — \(procedureName)"
            )

            Spacer()

            if let image = capturedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 270)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
                        .padding(.horizontal, Theme.Spacing.xl)

                    Button { capturedImage = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.white)
                            .shadow(color: .black.opacity(0.2), radius: 4)
                            .padding(Theme.Spacing.xl + 4)
                    }
                }
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    Button { showCamera = true } label: {
                        photoOptionRow(icon: "camera.fill", label: "Take Photo")
                    }

                    PhotosPicker(selection: $libraryItem, matching: .images) {
                        photoOptionRow(icon: "photo.on.rectangle.angled", label: "Choose from Library")
                    }
                    .onChange(of: libraryItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self) {
                                capturedImage = UIImage(data: data)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 4: Notes

    private var notesStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "How are you\nfeeling today?",
                subtitle: "Day \(dayNumber) — \(procedureName)"
            )

            Spacer()

            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Symptoms, mood,\nanything you've noticed…")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(Theme.Brand.charcoalRose.opacity(0.2))
                        .allowsHitTesting(false)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.top, 8)
                }
                TextEditor(text: $notes)
                    .font(.system(size: 26, weight: .light))
                    .foregroundColor(Theme.Brand.charcoalRose)
                    .tint(Theme.Brand.charcoalRose)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .frame(maxHeight: 260)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Bottom Navigation

    private var bottomNav: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if currentStep == totalSteps - 1 {
                Text("Not medical advice. Photos stored privately.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Brand.charcoalRose.opacity(0.45))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: Theme.Spacing.md) {
                if currentStep > startStep {
                    Button {
                        goingForward = false
                        withAnimation { currentStep -= 1 }
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.Brand.charcoalRose.opacity(0.65))
                            .frame(width: 52, height: 52)
                            .background(Theme.Brand.charcoalRose.opacity(0.1))
                            .clipShape(Circle())
                    }
                }

                Button {
                    if currentStep < totalSteps - 1 {
                        goingForward = true
                        withAnimation { currentStep += 1 }
                    } else {
                        Task {
                            isSaving = true
                            let imageData = capturedImage.flatMap {
                                $0.jpegData(compressionQuality: 0.75)
                            }
                            await onSave(
                                procedureId,
                                procedureName.trimmingCharacters(in: .whitespaces),
                                dayNumber,
                                entryDate,
                                notes.isEmpty ? nil : notes,
                                imageData
                            )
                            isSaving = false
                        }
                    }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text(currentStep < totalSteps - 1 ? "Continue" : "Save Entry")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        canAdvance && !isSaving
                            ? Theme.Brand.charcoalRose
                            : Theme.Brand.charcoalRose.opacity(0.25)
                    )
                    .clipShape(Capsule())
                }
                .disabled(!canAdvance || isSaving)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    // MARK: - Reusable Components

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(Theme.Brand.charcoalRose)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Theme.Brand.charcoalRose.opacity(0.5))
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.lg)
    }

    private func photoOptionRow(icon: String, label: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(Theme.Brand.charcoalRose)
                .frame(width: 28)
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.Brand.charcoalRose)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.Brand.charcoalRose.opacity(0.35))
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md + 4)
        .background(Theme.Brand.charcoalRose.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    // MARK: - Helpers

    private func recalculateDayNumber() {
        let cal = Calendar.current
        let procedureEntries = existingEntries.filter { $0.procedureId == procedureId }

        // Anchor: prefer a Day 0 entry, fall back to the earliest entry
        let anchorEntry: JournalEntry?
        if let d0 = procedureEntries.first(where: { $0.dayNumber == 0 }) {
            anchorEntry = d0
        } else {
            anchorEntry = procedureEntries.min(by: { $0.dayNumber < $1.dayNumber })
        }

        guard let anchor = anchorEntry else { return }

        let anchorDate = cal.startOfDay(for: anchor.entryDateAsDate)
        let selected = cal.startOfDay(for: entryDate)
        let diff = cal.dateComponents([.day], from: anchorDate, to: selected).day ?? 0
        dayNumber = max(0, anchor.dayNumber + diff)
    }
}
