//
//  AddJournalEntryView.swift
//  Renaissance Mobile
//

import SwiftUI
import PhotosUI

struct AddJournalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (String, String, Int, Date, String?, Data?) async -> Void

    // Procedure selection
    @State private var selectedProcedureId = ""
    @State private var selectedProcedureName = ""
    @State private var showProcedurePicker = false

    // Entry fields
    @State private var dayNumber = 0
    @State private var entryDate = Date()
    @State private var notes = ""

    // Photo
    @State private var capturedImage: UIImage?
    @State private var libraryItem: PhotosPickerItem?
    @State private var showCamera = false

    @State private var isSaving = false

    private var canSave: Bool {
        !selectedProcedureId.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {

                    // Procedure selector
                    sectionCard(title: "Procedure") {
                        Button {
                            showProcedurePicker = true
                        } label: {
                            HStack {
                                Text(selectedProcedureName.isEmpty ? "Select a procedure" : selectedProcedureName)
                                    .foregroundStyle(selectedProcedureName.isEmpty
                                        ? Theme.Colors.textSecondary
                                        : Theme.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                    }

                    // Day + date
                    sectionCard(title: "Recovery Day") {
                        VStack(spacing: Theme.Spacing.md) {
                            HStack {
                                Text("Day number")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                Stepper("\(dayNumber)", value: $dayNumber, in: 0...365)
                                    .labelsHidden()
                                Text(dayNumber == 0 ? "Day of procedure" : "Day \(dayNumber)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .frame(width: 100, alignment: .trailing)
                            }

                            Divider()

                            DatePicker("Entry date", selection: $entryDate, displayedComponents: .date)
                                .font(.system(size: 15))
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
                                selectedProcedureId,
                                selectedProcedureName,
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
            .sheet(isPresented: $showProcedurePicker) {
                JournalProcedurePickerSheet { id, name in
                    selectedProcedureId = id
                    selectedProcedureName = name
                    showProcedurePicker = false
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                PhotoCaptureView(capturedImage: $capturedImage)
            }
        }
    }

    // MARK: - Helpers

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

// MARK: - Procedure Picker Sheet

struct JournalProcedurePickerSheet: View {
    let onSelect: (String, String) -> Void
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [ProcedurePricing] {
        let all = ProcedurePricingData.all
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { pricing in
                Button {
                    onSelect(pricing.id, pricing.displayName)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pricing.displayName)
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(pricing.category)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search procedures")
            .navigationTitle("Select Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
