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

    // Procedure
    @State private var procedureName = ""

    // Entry fields
    @State private var dayNumber = 0
    @State private var entryDate = Date()
    @State private var notes = ""
    @State private var isDayAutoCalculated = false

    // Photo
    @State private var capturedImage: UIImage?
    @State private var libraryItem: PhotosPickerItem?
    @State private var showCamera = false

    @State private var isSaving = false

    /// Stable ID derived from the procedure name so entries for the same procedure group correctly.
    private var procedureId: String {
        procedureName
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }

    private var canSave: Bool {
        !procedureName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {

                    // Procedure name
                    sectionCard(title: "Procedure") {
                        TextField("e.g. Rhinoplasty, Lip Filler, BBL…", text: $procedureName)
                            .font(.system(size: 15))
                            .onChange(of: procedureName) { _, _ in recalculateDayNumber() }
                    }

                    // Day + date
                    sectionCard(title: "Recovery Day") {
                        VStack(spacing: Theme.Spacing.md) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Day number")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    if isDayAutoCalculated {
                                        Text("Auto-calculated from procedure date")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.Brand.mauveBerry)
                                    }
                                }
                                Spacer()
                                Stepper("\(dayNumber)", value: $dayNumber, in: 0...365) { _ in
                                    isDayAutoCalculated = false
                                }
                                .labelsHidden()
                                Text(dayNumber == 0 ? "Day of procedure" : "Day \(dayNumber)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .frame(width: 100, alignment: .trailing)
                            }

                            Divider()

                            DatePicker("Entry date", selection: $entryDate, displayedComponents: .date)
                                .font(.system(size: 15))
                                .onChange(of: entryDate) { _, _ in recalculateDayNumber() }
                        }
                    }

                    // Photo
                    sectionCard(title: "Photo (optional)") {
                        if let image = capturedImage {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))

                                Button {
                                    capturedImage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.white)
                                        .padding(8)
                                }
                            }
                        } else {
                            HStack(spacing: Theme.Spacing.lg) {
                                photoButton(icon: "camera.fill", label: "Camera") {
                                    showCamera = true
                                }
                                photoButton(icon: "photo.on.rectangle", label: "Library") { }
                                    .overlay(
                                        PhotosPicker(selection: $libraryItem, matching: .images) {
                                            Color.clear
                                        }
                                    )
                            }
                            .onChange(of: libraryItem) { _, item in
                                Task {
                                    if let data = try? await item?.loadTransferable(type: Data.self) {
                                        capturedImage = UIImage(data: data)
                                    }
                                }
                            }
                        }
                    }

                    // Notes
                    sectionCard(title: "Notes") {
                        TextField("How are you feeling? Any symptoms to log…", text: $notes, axis: .vertical)
                            .lineLimit(4...8)
                            .font(.system(size: 15))
                    }

                    // Disclaimer
                    Text("Photos are stored privately and used only for your personal recovery tracking. AI analysis is for reference only — not medical advice.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.sm)
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("New Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
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
                    } label: {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundStyle(canSave ? Theme.Brand.mauveBerry : Theme.Colors.textSecondary)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                PhotoCaptureView(capturedImage: $capturedImage)
            }
        }
    }

    // MARK: - Helpers

    /// Auto-calculates dayNumber from the D0 entry of the selected procedure.
    /// If no D0 entry exists for this procedure, the day number stays as-is.
    private func recalculateDayNumber() {
        guard !procedureId.isEmpty else { return }
        let procedureEntries = existingEntries.filter { $0.procedureId == procedureId }
        guard let d0Entry = procedureEntries.first(where: { $0.dayNumber == 0 }) else { return }

        let cal = Calendar.current
        let d0 = cal.startOfDay(for: d0Entry.entryDateAsDate)
        let selected = cal.startOfDay(for: entryDate)
        let days = cal.dateComponents([.day], from: d0, to: selected).day ?? 0
        dayNumber = max(0, days)
        isDayAutoCalculated = true
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)

            VStack(alignment: .leading) {
                content()
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .fill(Color.white)
                    .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius,
                            x: Theme.Shadow.card.x, y: Theme.Shadow.card.y)
            )
        }
    }

    private func photoButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .fill(Theme.Brand.softBlush)
                        .frame(height: 80)
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.Brand.mauveBerry)
                }
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
