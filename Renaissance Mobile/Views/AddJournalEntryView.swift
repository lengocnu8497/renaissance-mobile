//
//  AddJournalEntryView.swift
//  Renaissance Mobile
//

import SwiftUI
import PhotosUI

struct AddJournalEntryView: View {
    @Environment(\.dismiss) private var dismiss

    let vm: JournalViewModel

    // Navigation
    @State private var currentStep: Int
    @State private var goingForward = true
    private let startStep: Int
    private let totalSteps = 6

    // Procedure
    @State private var procedureName: String
    @State private var showNewProcedureField = false

    init(vm: JournalViewModel, prefilledProcedureName: String? = nil) {
        self.vm = vm
        let step = prefilledProcedureName != nil ? 1 : 0
        self.startStep = step
        _currentStep = State(initialValue: step)
        _procedureName = State(initialValue: prefilledProcedureName ?? "")
    }

    // Entry fields
    @State private var entryDate = Date()
    @State private var notes = ""
    @State private var bruisingLevel = 0
    @State private var swellingLevel = 0
    @State private var rednessLevel = 0

    // Save state
    @State private var isSaving = false

    // Reminder step (step 5) — populated after a successful save
    @State private var reminderConfig: ProcedureReminderConfig? = nil
    @State private var reminderEnabled = true
    @State private var reminderDate = Date()
    @State private var followUpMilestones: [FollowUpMilestone] = []
    @State private var isSchedulingReminder = false

    // Photo
    @State private var capturedImage: UIImage?
    @State private var libraryItem: PhotosPickerItem?
    @State private var showCamera = false

    // Derived day number — days from earliest existing entry for this procedure
    private var dayNumber: Int {
        let pid = makeId(procedureName)
        guard !pid.isEmpty else { return 0 }
        let relevant = vm.entries.filter { $0.procedureId == pid }
        guard let earliest = relevant.min(by: { $0.entryDateAsDate < $1.entryDateAsDate }) else {
            return 0
        }
        let cal = Calendar.current
        let diff = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: earliest.entryDateAsDate),
            to: cal.startOfDay(for: entryDate)
        ).day ?? 0
        return max(0, diff)
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

                ZStack {
                    switch currentStep {
                    case 0: procedureStep
                    case 1: dayStep
                    case 2: metricsStep
                    case 3: photoStep
                    case 5: reminderStep
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
        .interactiveDismissDisabled(isSaving)
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
            .disabled(isSaving)

            Spacer()

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

    // MARK: - Step 0: Procedure

    private var procedureStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "What procedure\nare you tracking?",
                subtitle: Self.dateFormatter.string(from: Date())
            )

            if vm.proceduresWithEntries.isEmpty || showNewProcedureField {
                // ── Text-input mode ──────────────────────────────
                Spacer()
                newProcedureInputView(showBack: !vm.proceduresWithEntries.isEmpty)
                Spacer()
                Spacer()
            } else {
                // ── Picker mode ──────────────────────────────────
                ScrollView(showsIndicators: false) {
                    previousProceduresList(procedures: vm.proceduresWithEntries)
                        .padding(.top, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.xl)
                }
            }
        }
    }

    private func previousProceduresList(
        procedures: [(id: String, name: String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR PROCEDURES")
                .font(.system(size: 10, weight: .semibold))
                .kerning(2)
                .foregroundColor(Theme.Brand.charcoalRose.opacity(0.45))
                .padding(.horizontal, Theme.Spacing.xl)

            VStack(spacing: 8) {
                ForEach(procedures, id: \.id) { proc in
                    let isSelected = procedureName == proc.name
                    Button {
                        procedureName = proc.name
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(
                                    isSelected
                                        ? Theme.Brand.charcoalRose
                                        : Theme.Brand.charcoalRose.opacity(0.25)
                                )
                            Text(proc.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Theme.Brand.charcoalRose)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            isSelected
                                ? Theme.Brand.charcoalRose.opacity(0.14)
                                : Theme.Brand.charcoalRose.opacity(0.07)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            // New procedure row
            Button {
                procedureName = ""
                showNewProcedureField = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Brand.charcoalRose.opacity(0.55))
                    Text("New procedure")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.Brand.charcoalRose.opacity(0.65))
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, 6)
            }
            .buttonStyle(.plain)
        }
    }

    private func newProcedureInputView(showBack: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if showBack {
                Button {
                    procedureName = ""
                    showNewProcedureField = false
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("My procedures")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Theme.Brand.charcoalRose.opacity(0.6))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, 20)
            }

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
        }
    }

    // MARK: - Step 1: Date

    private var dayStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "When is this\nentry for?",
                subtitle: procedureName
            )

            Spacer()

            VStack(spacing: Theme.Spacing.xl) {
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

                Text("Auto-calculated from your first entry date")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Brand.charcoalRose.opacity(0.55))
                    .padding(.horizontal, Theme.Spacing.xl)

                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Brand.charcoalRose.opacity(0.6))
                    DatePicker("", selection: $entryDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .tint(Theme.Brand.charcoalRose)
                        .colorScheme(.light)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.sm)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 2: Photo

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

    // MARK: - Step 3: Recovery Metrics

    private var metricsStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "How are you\nrecovering?",
                subtitle: "Day \(dayNumber) — \(procedureName)"
            )

            Spacer()

            VStack(spacing: 12) {
                metricRow(
                    label: "Bruising",
                    icon: "drop.fill",
                    value: $bruisingLevel,
                    color: Color(hex: "#7B4B6A")
                )
                metricRow(
                    label: "Swelling",
                    icon: "waveform.path",
                    value: $swellingLevel,
                    color: Color(hex: "#B76E79")
                )
                metricRow(
                    label: "Redness",
                    icon: "flame.fill",
                    value: $rednessLevel,
                    color: Color(hex: "#E8635A")
                )
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Text("Tap a segment to rate 0–10. Tap again to clear.")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Theme.Brand.charcoalRose.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)

            Spacer()
            Spacer()
        }
    }

    private func metricRow(label: String, icon: String, value: Binding<Int>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Brand.charcoalRose)
                Spacer()
                Text(levelLabel(value.wrappedValue))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(value.wrappedValue == 0
                        ? Theme.Brand.charcoalRose.opacity(0.35)
                        : color)
                    .frame(minWidth: 58, alignment: .trailing)
                    .animation(.easeInOut(duration: 0.15), value: value.wrappedValue)
            }

            HStack(spacing: 3) {
                ForEach(0...10, id: \.self) { lvl in
                    Capsule()
                        .fill(lvl <= value.wrappedValue ? color : color.opacity(0.12))
                        .frame(height: 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Tap the current level to reset to 0
                            if lvl == value.wrappedValue {
                                value.wrappedValue = 0
                            } else {
                                value.wrappedValue = lvl
                            }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: value.wrappedValue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Theme.Brand.charcoalRose.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func levelLabel(_ value: Int) -> String {
        switch value {
        case 0:     return "None"
        case 1...3: return "Mild"
        case 4...6: return "Moderate"
        case 7...9: return "Severe"
        case 10:    return "Extreme"
        default:    return "None"
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
            // Disclaimer on the notes step (step 4, previously the last step)
            if currentStep == totalSteps - 2 {
                Text("Not medical advice. Photos stored privately.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Brand.charcoalRose.opacity(0.45))
                    .multilineTextAlignment(.center)
            }

            if currentStep == totalSteps - 1 {
                // Reminder step — own nav layout
                reminderBottomNav
            } else {
                HStack(spacing: Theme.Spacing.md) {
                    // Back button: hidden on step 5 (reminder) since entry is already saved
                    if currentStep > startStep && currentStep < totalSteps - 1 {
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
                        .disabled(isSaving)
                    }

                    Button {
                        if currentStep < totalSteps - 2 {
                            // Steps 0–3: advance
                            goingForward = true
                            withAnimation { currentStep += 1 }
                        } else {
                            // Step 4 (notes): save entry, then advance to reminder step
                            saveEntry()
                        }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(currentStep < totalSteps - 2 ? "Continue" : "Save Entry")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            (canAdvance && !isSaving)
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
    }

    // MARK: - Step 5: Reminder

    private var reminderStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: (reminderConfig?.isSurgical == true)
                    ? "Schedule your\nfollow-ups"
                    : "One last thing",
                subtitle: procedureName.trimmingCharacters(in: .whitespaces)
            )

            Spacer()

            if let config = reminderConfig {
                if config.isSurgical {
                    surgicalMilestonesContent(config: config)
                } else {
                    retreatmentReminderContent(config: config)
                }
            }

            Spacer()
            Spacer()
        }
    }

    private func retreatmentReminderContent(config: ProcedureReminderConfig) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Context note
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Brand.charcoalRose.opacity(0.55))
                    .padding(.top, 1)
                Text(config.contextNote)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Theme.Brand.charcoalRose.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            // Toggle + date picker
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Remind me")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.Brand.charcoalRose)
                    Spacer()
                    Toggle("", isOn: $reminderEnabled)
                        .tint(Theme.Brand.charcoalRose)
                        .labelsHidden()
                }
                .padding(.horizontal, Theme.Spacing.xl)

                if reminderEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "calendar")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.Brand.charcoalRose.opacity(0.55))
                            if let label = config.retreatmentRangeLabel {
                                Text("Suggested: \(label) from today")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(Theme.Brand.charcoalRose.opacity(0.5))
                            }
                            Spacer()
                            DatePicker(
                                "",
                                selection: $reminderDate,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .tint(Theme.Brand.charcoalRose)
                            .colorScheme(.light)
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: reminderEnabled)
        }
    }

    private func surgicalMilestonesContent(config: ProcedureReminderConfig) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Context note
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Brand.charcoalRose.opacity(0.55))
                    .padding(.top, 1)
                Text(config.contextNote)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Brand.charcoalRose.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            // Milestone rows
            VStack(spacing: 6) {
                ForEach(followUpMilestones.indices, id: \.self) { idx in
                    let milestone = followUpMilestones[idx]
                    let milestoneDate = Calendar.current.date(
                        byAdding: .day,
                        value: milestone.daysFromProcedure,
                        to: entryDate
                    ) ?? entryDate
                    let isPast = milestoneDate <= Date()

                    Button {
                        guard !isPast else { return }
                        followUpMilestones[idx].enabled.toggle()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: milestone.enabled ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(
                                    isPast
                                        ? Theme.Brand.charcoalRose.opacity(0.18)
                                        : (milestone.enabled
                                            ? Theme.Brand.charcoalRose
                                            : Theme.Brand.charcoalRose.opacity(0.28))
                                )

                            Text(milestone.label)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(
                                    isPast
                                        ? Theme.Brand.charcoalRose.opacity(0.28)
                                        : Theme.Brand.charcoalRose
                                )

                            Spacer()

                            Text(Self.dateFormatter.string(from: milestoneDate))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(
                                    isPast
                                        ? Theme.Brand.charcoalRose.opacity(0.22)
                                        : Theme.Brand.charcoalRose.opacity(0.55)
                                )
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            milestone.enabled && !isPast
                                ? Theme.Brand.charcoalRose.opacity(0.1)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.Brand.charcoalRose.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPast)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Text("Dates calculated from your procedure date")
                .font(.system(size: 11))
                .foregroundColor(Theme.Brand.charcoalRose.opacity(0.38))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, Theme.Spacing.xl)
        }
    }

    // MARK: - Reminder Bottom Nav

    private var reminderBottomNav: some View {
        VStack(spacing: 12) {
            Button {
                isSchedulingReminder = true
                Task { @MainActor in
                    await scheduleSelectedReminders()
                    isSchedulingReminder = false
                    dismiss()
                }
            } label: {
                Group {
                    if isSchedulingReminder {
                        ProgressView().tint(.white)
                    } else {
                        Text(reminderButtonLabel)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    isSchedulingReminder
                        ? Theme.Brand.charcoalRose.opacity(0.5)
                        : Theme.Brand.charcoalRose
                )
                .clipShape(Capsule())
            }
            .disabled(isSchedulingReminder)

            Button {
                dismiss()
            } label: {
                Text("Skip")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Theme.Brand.charcoalRose.opacity(0.55))
                    .padding(.vertical, 8)
            }
            .disabled(isSchedulingReminder)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xl)
    }

    private var reminderButtonLabel: String {
        guard let config = reminderConfig else { return "Done" }
        if config.isSurgical {
            let count = followUpMilestones.filter(\.enabled).count
            return count == 0 ? "Done" : "Set \(count) Reminder\(count == 1 ? "" : "s")"
        }
        return reminderEnabled ? "Set Reminder" : "Done"
    }

    // MARK: - Schedule Reminders

    private func scheduleSelectedReminders() async {
        guard let config = reminderConfig else { return }
        let name = procedureName.trimmingCharacters(in: .whitespaces)

        if config.isSurgical {
            var reminders: [TreatmentReminder] = []
            for milestone in followUpMilestones where milestone.enabled {
                let date = Calendar.current.date(
                    byAdding: .day, value: milestone.daysFromProcedure, to: entryDate
                ) ?? entryDate
                guard date > Date() else { continue }
                let reminder = TreatmentReminder(
                    procedureName: name,
                    procedureDate: entryDate,
                    reminderDate: date,
                    label: milestone.label,
                    kind: .followUp
                )
                await TreatmentNotificationService.shared.schedule(reminder)
                reminders.append(reminder)
            }
            TreatmentReminderStore.shared.saveAll(reminders)
        } else if reminderEnabled {
            let reminder = TreatmentReminder(
                procedureName: name,
                procedureDate: entryDate,
                reminderDate: reminderDate,
                label: "Next \(config.procedureDisplayName)",
                kind: .retreatment
            )
            await TreatmentNotificationService.shared.schedule(reminder)
            TreatmentReminderStore.shared.save(reminder)
        }
    }

    // MARK: - Save

    private func saveEntry() {
        isSaving = true
        Task { @MainActor in
            let photoData = capturedImage.flatMap { $0.jpegData(compressionQuality: 0.85) }
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let pid = makeId(procedureName)
            let trimmedName = procedureName.trimmingCharacters(in: .whitespaces)

            let success = await vm.addEntry(
                procedureId: pid,
                procedureName: trimmedName,
                dayNumber: dayNumber,
                entryDate: entryDate,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                photoData: photoData,
                bruisingLevel: bruisingLevel > 0 ? bruisingLevel : nil,
                swellingLevel: swellingLevel > 0 ? swellingLevel : nil,
                rednessLevel: rednessLevel > 0 ? rednessLevel : nil
            )

            if success {
                // Set up reminder step from the procedure that was just saved
                let name = procedureName.trimmingCharacters(in: .whitespaces)
                let config = ProcedureReminderConfig.config(for: name)
                reminderConfig = config
                reminderDate = config.defaultReminderDate(from: entryDate)
                // Pre-populate milestones; auto-disable any whose dates are already past
                followUpMilestones = config.followUpMilestones.map { m in
                    let date = Calendar.current.date(
                        byAdding: .day, value: m.daysFromProcedure, to: entryDate
                    ) ?? entryDate
                    guard date > Date() else {
                        var disabled = m; disabled.enabled = false; return disabled
                    }
                    return m
                }
                isSaving = false
                goingForward = true
                withAnimation { currentStep = 5 }
            } else {
                isSaving = false
            }
        }
    }

    // MARK: - Helpers

    /// Converts a human-readable procedure name to a stable slug used as procedureId.
    private func makeId(_ name: String) -> String {
        name.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

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
}
