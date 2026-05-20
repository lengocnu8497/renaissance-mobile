//
//  AddJournalEntryView.swift
//  Renaissance Mobile
//

import SwiftUI
import PhotosUI
import StoreKit

// MARK: - Local design tokens (violet palette)
private enum AEV {
    static let ink      = Color(hex: "#2D2575")
    static let muted    = Color(hex: "#7B6FC0")
    static let pale     = Color(hex: "#A9A3D4")
    static let primary  = Color(hex: "#6C63FF")
    static let soft     = Color(hex: "#EAE7FF")
    static let line     = Color(hex: "#D4CCFF")
    static let success  = Color(hex: "#5BBF84")
    static let card     = Color.white
    // Metric tints — semantic, not violet
    static let pain     = Color(hex: "#E07373")
    static let swell    = Color(hex: "#6B9ECC")
    static let bruise   = Color(hex: "#7B70D4")
    static let redness  = Color(hex: "#C97070")
}

struct AddJournalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    let vm: JournalViewModel

    // Steps 0–2 are the entry flow; 3 is celebration
    @State private var currentStep: Int
    @State private var goingForward = true
    private let startStep: Int
    private let totalSteps = 3

    @State private var procedureName: String
    @State private var showNewProcedureField = false
    @State private var entryDate = Date()
    @State private var notes = ""
    @State private var painLevel = 0
    @State private var bruisingLevel = 0
    @State private var swellingLevel = 0
    @State private var rednessLevel = 0
    @State private var isSaving = false
    @State private var capturedImage: UIImage?
    @State private var libraryItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var showInsights = false

    init(vm: JournalViewModel, prefilledProcedureName: String? = nil) {
        self.vm = vm
        let step = prefilledProcedureName != nil ? 1 : 0
        self.startStep = step
        _currentStep = State(initialValue: step)
        _procedureName = State(initialValue: prefilledProcedureName ?? "")
    }

    private var dayNumber: Int {
        let pid = makeId(procedureName)
        guard !pid.isEmpty else { return 0 }
        let relevant = vm.entries.filter { $0.procedureId == pid }
        guard let earliest = relevant.min(by: { $0.entryDateAsDate < $1.entryDateAsDate }) else { return 0 }
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day],
            from: cal.startOfDay(for: earliest.entryDateAsDate),
            to: cal.startOfDay(for: entryDate)).day ?? 0)
    }

    private var canAdvance: Bool {
        currentStep == 0
            ? !procedureName.trimmingCharacters(in: .whitespaces).isEmpty
            : true
    }

    private var loggedStreak: Int {
        let pid = makeId(procedureName)
        guard !pid.isEmpty else { return 1 }
        let cal = Calendar.current
        let relevant = vm.entries.filter { $0.procedureId == pid }
        var streak = 0
        var check = cal.startOfDay(for: Date())
        while relevant.contains(where: { cal.startOfDay(for: $0.entryDateAsDate) == check }) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: check) else { break }
            check = prev
        }
        return max(streak, 1)
    }

    private var procedureEntryCount: Int {
        let pid = makeId(procedureName)
        return vm.entries.filter { $0.procedureId == pid }.count
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#F8F8FF"), Color(hex: "#EEEEFF")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, Theme.Spacing.md)

                ZStack {
                    switch currentStep {
                    case 0:  procedureStep
                    case 1:  metricsStep
                    case 2:  notesPhotoStep
                    default: celebrationStep
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
        .onAppear { Analytics.journalEntryStarted() }
        .interactiveDismissDisabled(isSaving)
        .fullScreenCover(isPresented: $showCamera) {
            PhotoCaptureView(capturedImage: $capturedImage)
        }
        .sheet(isPresented: $showInsights) {
            HomeInsightsView(vm: vm, procedureName: procedureName)
        }
        .photosPicker(isPresented: $showLibraryPicker, selection: $libraryItem, matching: .images)
        .onChange(of: libraryItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    capturedImage = UIImage(data: data)
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            if currentStep > startStep && currentStep < totalSteps {
                Button {
                    goingForward = false
                    withAnimation { currentStep -= 1 }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AEV.muted)
                        .frame(width: 36, height: 36)
                        .background(AEV.soft)
                        .clipShape(Circle())
                }
                .disabled(isSaving)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }

            Spacer()

            HStack(spacing: 5) {
                ForEach(startStep..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(
                            currentStep == 3
                                ? AEV.success
                                : (i <= currentStep ? AEV.primary : AEV.line)
                        )
                        .frame(width: i == currentStep ? 22 : 6, height: 6)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentStep)
                }
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AEV.muted)
                    .frame(width: 36, height: 36)
                    .background(AEV.soft)
                    .clipShape(Circle())
            }
            .disabled(isSaving)
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Step 0: Procedure

    private var procedureStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "What procedure\nare you tracking?", subtitle: "")

            if vm.proceduresWithEntries.isEmpty || showNewProcedureField {
                Spacer()
                newProcedureInputView(showBack: !vm.proceduresWithEntries.isEmpty)
                Spacer()
                Spacer()
            } else {
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
                .foregroundColor(AEV.pale)
                .padding(.horizontal, Theme.Spacing.xl)

            VStack(spacing: 8) {
                ForEach(procedures, id: \.id) { proc in
                    let isSelected = procedureName == proc.name
                    Button { procedureName = proc.name } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? AEV.primary : AEV.line)
                            Text(proc.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AEV.ink)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(isSelected ? AEV.soft : AEV.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    isSelected ? AEV.primary.opacity(0.3) : AEV.line.opacity(0.5),
                                    lineWidth: 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Button {
                procedureName = ""
                showNewProcedureField = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18))
                        .foregroundColor(AEV.muted)
                    Text("New procedure")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AEV.muted)
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
                    .foregroundColor(AEV.muted)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, 20)
            }

            ZStack(alignment: .topLeading) {
                if procedureName.isEmpty {
                    Text("Rhinoplasty,\nLip filler…")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(AEV.line)
                        .allowsHitTesting(false)
                }
                TextField("", text: $procedureName, axis: .vertical)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(AEV.ink)
                    .tint(AEV.primary)
                    .lineLimit(3)
                    .submitLabel(.done)
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
    }

    // MARK: - Step 1: Metrics

    private var metricsStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "How are you\nfeeling today?",
                subtitle: "Day \(dayNumber) · \(procedureName)"
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    metricRow(label: "Pain",     icon: "bolt.fill",     value: $painLevel,     color: AEV.pain)
                    metricRow(label: "Swelling", icon: "waveform.path", value: $swellingLevel, color: AEV.swell)
                    metricRow(label: "Bruising", icon: "drop.fill",     value: $bruisingLevel, color: AEV.bruise)
                    metricRow(label: "Redness",  icon: "flame.fill",    value: $rednessLevel,  color: AEV.redness)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }

            Text("Tap a segment to rate 0–10 · Tap again to clear")
                .font(.system(size: 11))
                .foregroundColor(AEV.pale)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)
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
                    .foregroundColor(AEV.ink)
                Spacer()
                Text(levelLabel(value.wrappedValue))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(value.wrappedValue == 0 ? AEV.pale : color)
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
                            value.wrappedValue = (lvl == value.wrappedValue) ? 0 : lvl
                        }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: value.wrappedValue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(AEV.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AEV.line.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: AEV.primary.opacity(0.05), radius: 4, y: 2)
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

    // MARK: - Step 2: Notes + Photo

    private var notesPhotoStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "Anything to\nadd?",
                subtitle: "Day \(dayNumber) · \(procedureName)"
            )

            VStack(spacing: 14) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AEV.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(AEV.line.opacity(0.6), lineWidth: 1)
                        )
                        .shadow(color: AEV.primary.opacity(0.05), radius: 6, y: 2)

                    if notes.isEmpty {
                        Text("Symptoms, mood,\nanything you've noticed…")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(AEV.pale)
                            .allowsHitTesting(false)
                            .padding(16)
                    }
                    TextEditor(text: $notes)
                        .font(.system(size: 16))
                        .foregroundColor(AEV.ink)
                        .tint(AEV.primary)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .padding(12)
                }
                .frame(minHeight: 150, maxHeight: 210)

                if let image = capturedImage {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        Button { capturedImage = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.2), radius: 4)
                                .padding(8)
                        }
                    }
                } else {
                    photoPickerRow
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.lg)

            Text("Not medical advice · Photos stored privately")
                .font(.system(size: 10.5))
                .foregroundColor(AEV.pale)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
        }
    }

    private var photoPickerRow: some View {
        Menu {
            Button {
                showCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera.fill")
            }
            Button {
                showLibraryPicker = true
            } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle.angled")
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AEV.soft)
                        .frame(width: 44, height: 44)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AEV.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add a photo")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AEV.ink)
                    Text("Camera or library · Optional")
                        .font(.system(size: 11))
                        .foregroundColor(AEV.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AEV.pale)
            }
            .padding(16)
            .background(AEV.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                    .foregroundColor(AEV.line)
            )
        }
    }

    // MARK: - Step 3: Celebration

    private var celebrationStep: some View {
        ZStack {
            ConfettiView()
            celebrationContent
        }
    }

    private var celebrationContent: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack(alignment: .center) {
                LottieView(name: "flower-growing", loop: true)
                    .frame(width: 200, height: 200)
                    .offset(y: 30)
                LottieView(name: "water", loop: true)
                    .frame(width: 140, height: 140)
                    .offset(x: -70, y: -55)
            }
            .frame(width: 260, height: 270)

            Text("Entry saved!")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(AEV.ink)
                .padding(.top, 16)

            Text("You showed up for yourself today.\nSmall, steady care is how everything heals.")
                .font(.system(size: 14))
                .foregroundColor(AEV.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 14)
                .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - Confetti

private struct ConfettiParticle: Identifiable {
    let id: Int
    let xFraction: CGFloat
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let delay: Double
    let duration: Double
    let isCircle: Bool
}

private struct ConfettiView: View {
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ForEach(Self.particles) { p in
                (p.isCircle
                    ? AnyView(Circle().fill(p.color))
                    : AnyView(RoundedRectangle(cornerRadius: 2).fill(p.color))
                )
                .frame(width: p.width, height: p.height)
                .position(x: p.xFraction * geo.size.width, y: animate ? geo.size.height + 30 : -20)
                .opacity(0.85)
                .animation(
                    .linear(duration: p.duration).delay(p.delay).repeatForever(autoreverses: false),
                    value: animate
                )
            }
        }
        .onAppear { animate = true }
    }

    private static let particles: [ConfettiParticle] = {
        let colors: [Color] = [
            Color(hex: "#6C63FF"), Color(hex: "#EAE7FF"), Color(hex: "#9B95E0"),
            Color(hex: "#D4CCFF"), Color(hex: "#5BBF84"), Color(hex: "#FFD166"),
            Color(hex: "#FF9F9F"), Color(hex: "#4A41C8"), Color(hex: "#A9A3D4"),
            Color(hex: "#B0F0D8")
        ]
        let xs: [CGFloat] = [
            0.05, 0.12, 0.18, 0.24, 0.30, 0.36, 0.42, 0.48, 0.54, 0.60,
            0.66, 0.72, 0.78, 0.84, 0.90, 0.96, 0.09, 0.21, 0.33, 0.45,
            0.57, 0.69, 0.81, 0.93, 0.15, 0.27, 0.39, 0.51, 0.63, 0.75,
            0.87, 0.03, 0.25, 0.50, 0.75, 0.10
        ]
        let delays: [Double] = [
            0.00, 0.30, 0.60, 0.10, 0.40, 0.70, 0.20, 0.50, 0.80, 0.15,
            0.45, 0.75, 0.25, 0.55, 0.85, 0.35, 0.65, 0.95, 0.05, 0.50,
            0.20, 0.70, 0.40, 0.90, 0.10, 0.60, 0.30, 0.80, 0.00, 0.40,
            0.70, 0.20, 0.50, 0.80, 0.30, 0.60
        ]
        let durations: [Double] = [
            2.8, 3.2, 2.5, 3.5, 2.7, 3.0, 2.9, 3.3, 2.6, 3.1,
            2.8, 3.4, 2.5, 3.0, 2.7, 3.2, 2.9, 3.5, 2.6, 3.0,
            2.8, 3.2, 2.5, 3.3, 2.7, 3.0, 2.9, 3.4, 2.6, 3.1,
            2.8, 3.0, 2.5, 3.2, 2.7, 3.3
        ]
        let widths: [CGFloat] = [
            7, 5, 9, 6, 8, 10, 5, 7, 9, 6,
            8, 7, 5, 9, 6, 8, 7, 5, 9, 6,
            8, 7, 5, 9, 6, 8, 7, 5, 9, 6,
            8, 7, 5, 9, 6, 8
        ]
        return xs.enumerated().map { i, x in
            let w = widths[i % widths.count]
            let circle = i % 3 == 0
            return ConfettiParticle(
                id: i,
                xFraction: x,
                color: colors[i % colors.count],
                width: w,
                height: circle ? w : w * 1.6,
                delay: delays[i % delays.count],
                duration: durations[i % durations.count],
                isCircle: circle
            )
        }
    }()
}

extension AddJournalEntryView {

    // MARK: - Bottom Navigation

    private var bottomNav: some View {
        Group {
            if currentStep == 3 {
                VStack(spacing: 8) {
                    ctaButton(label: "View my insights") { showInsights = true }
                    ghostButton(label: "Done") { dismiss() }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            } else {
                VStack(spacing: 8) {
                    ctaButton(
                        label: currentStep == 2 ? "Save Entry" : "Continue",
                        isLoading: isSaving,
                        enabled: canAdvance && !isSaving
                    ) {
                        if currentStep < 2 {
                            goingForward = true
                            withAnimation { currentStep += 1 }
                        } else {
                            saveEntry()
                        }
                    }
                    if currentStep == 1 {
                        ghostButton(label: "Skip all metrics") {
                            goingForward = true
                            withAnimation { currentStep += 1 }
                        }
                    } else if currentStep == 2 {
                        ghostButton(label: "Save without notes") { saveEntry() }
                            .disabled(isSaving)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
    }

    private func ctaButton(
        label: String,
        isLoading: Bool = false,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(enabled ? AEV.primary : AEV.primary.opacity(0.35))
            .clipShape(Capsule())
            .shadow(color: enabled ? AEV.primary.opacity(0.30) : .clear, radius: 10, y: 4)
        }
        .disabled(!enabled)
    }

    private func ghostButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AEV.muted)
                .frame(height: 36)
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
                painLevel: painLevel > 0 ? painLevel : nil,
                bruisingLevel: bruisingLevel > 0 ? bruisingLevel : nil,
                swellingLevel: swellingLevel > 0 ? swellingLevel : nil,
                rednessLevel: rednessLevel > 0 ? rednessLevel : nil
            )

            isSaving = false
            if success {
                Analytics.journalEntrySaved(
                    procedure: trimmedName,
                    dayNumber: dayNumber,
                    hasPhoto: photoData != nil,
                    hasNotes: !trimmedNotes.isEmpty,
                    painLevel: painLevel,
                    swellingLevel: swellingLevel,
                    bruisingLevel: bruisingLevel,
                    rednessLevel: rednessLevel,
                    entryCount: procedureEntryCount
                )
                goingForward = true
                withAnimation { currentStep = 3 }
                if vm.entries.count == 1,
                   !UserDefaults.standard.bool(forKey: "rena.hasRequestedReview") {
                    UserDefaults.standard.set(true, forKey: "rena.hasRequestedReview")
                    try? await Task.sleep(for: .seconds(2.5))
                    requestReview()
                }
            }
        }
    }

    // MARK: - Helpers

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
                .foregroundColor(AEV.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(AEV.muted)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.lg)
    }
}
