//
//  SetReminderSheet.swift
//  Renaissance Mobile
//
//  Standalone reminder-scheduling sheet, surfaced when an urgent InsightFlag
//  fires with no follow-up reminder scheduled for that procedure.
//  Mirrors the step-5 UI from AddJournalEntryView but lives as a full sheet
//  with its own chrome so it can be presented from any context.
//

import SwiftUI

// MARK: - Design tokens (mirrors PhotoJournalView's J namespace)

private enum SR {
    static let bg       = Color(hex: "#FFF8F6")
    static let primary  = Color(hex: "#8E4C5C")
    static let gradA    = Color(hex: "#6B3346")
    static let gradB    = Color(hex: "#B76E79")
    static let accent   = Color(hex: "#C4929A")
    static let textHi   = Color(hex: "#3D2B2E")
    static let textLo   = Color(hex: "#B8A9AB")
    static let border   = Color(hex: "#C4929A").opacity(0.18)
}

// MARK: - View

struct SetReminderSheet: View {
    let procedureName: String
    let procedureDate: Date

    @Environment(\.dismiss) private var dismiss

    // Populated from ProcedureReminderConfig on init
    private let config: ProcedureReminderConfig

    @State private var reminderEnabled = true
    @State private var reminderDate: Date
    @State private var followUpMilestones: [FollowUpMilestone]
    @State private var isScheduling = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
    }()

    init(procedureName: String, procedureDate: Date) {
        self.procedureName = procedureName
        self.procedureDate = procedureDate

        let cfg = ProcedureReminderConfig.config(for: procedureName)
        self.config = cfg

        _reminderDate = State(initialValue: cfg.defaultReminderDate(from: procedureDate))
        _followUpMilestones = State(initialValue: cfg.followUpMilestones.map { m in
            let date = Calendar.current.date(
                byAdding: .day, value: m.daysFromProcedure, to: procedureDate
            ) ?? procedureDate
            if date <= Date() { var d = m; d.enabled = false; return d }
            return m
        })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            SR.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(SR.accent.opacity(0.35))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(config.isSurgical ? "Schedule follow-ups" : "Set a reminder")
                                .font(.system(size: 24, weight: .semibold, design: .serif))
                                .foregroundColor(SR.textHi)

                            HStack(spacing: 6) {
                                // Urgency pill
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 9, weight: .semibold))
                                    Text("Flagged concern")
                                        .font(.custom("Outfit-SemiBold", size: 10))
                                        .kerning(0.5)
                                }
                                .foregroundColor(SR.gradB)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(SR.gradB.opacity(0.10))
                                .clipShape(Capsule())

                                Text("·  \(procedureName)")
                                    .font(.custom("Outfit-Regular", size: 12))
                                    .foregroundColor(SR.textLo)
                            }
                        }

                        Spacer()

                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(SR.textHi)
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.8))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(SR.border, lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                Divider()
                    .background(SR.border)
                    .padding(.horizontal, 24)

                // Body
                ScrollView(showsIndicators: false) {
                    if config.isSurgical {
                        surgicalContent
                    } else {
                        retreatmentContent
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    footer
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Retreatment Content

    private var retreatmentContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Context note
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundColor(SR.accent)
                    .padding(.top, 1)
                Text(config.contextNote)
                    .font(.custom("Outfit-Regular", size: 14))
                    .foregroundColor(SR.textHi)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(Color.white.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SR.border, lineWidth: 1))

            // Toggle
            HStack {
                Text("Remind me")
                    .font(.custom("Outfit-SemiBold", size: 15))
                    .foregroundColor(SR.textHi)
                Spacer()
                Toggle("", isOn: $reminderEnabled)
                    .tint(SR.primary)
                    .labelsHidden()
            }
            .padding(.horizontal, 4)

            // Date picker (animated)
            if reminderEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    if let label = config.retreatmentRangeLabel {
                        Text("Suggested: \(label) from today")
                            .font(.custom("Outfit-Regular", size: 11))
                            .foregroundColor(SR.textLo)
                    }
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 13))
                            .foregroundColor(SR.accent)
                        Spacer()
                        DatePicker("", selection: $reminderDate, in: Date()..., displayedComponents: .date)
                            .labelsHidden()
                            .tint(SR.primary)
                    }
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(SR.border, lineWidth: 1))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: reminderEnabled)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Surgical Content

    private var surgicalContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Context note
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 14))
                    .foregroundColor(SR.accent)
                    .padding(.top, 1)
                Text(config.contextNote)
                    .font(.custom("Outfit-Regular", size: 14))
                    .foregroundColor(SR.textHi)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(Color.white.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SR.border, lineWidth: 1))

            // Milestone rows
            VStack(spacing: 8) {
                ForEach(followUpMilestones.indices, id: \.self) { idx in
                    let milestone = followUpMilestones[idx]
                    let milestoneDate = Calendar.current.date(
                        byAdding: .day, value: milestone.daysFromProcedure, to: procedureDate
                    ) ?? procedureDate
                    let isPast = milestoneDate <= Date()

                    Button {
                        guard !isPast else { return }
                        followUpMilestones[idx].enabled.toggle()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: milestone.enabled ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(
                                    isPast ? SR.border :
                                    (milestone.enabled ? SR.primary : SR.textLo.opacity(0.4))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(milestone.label)
                                    .font(.custom("Outfit-SemiBold", size: 13))
                                    .foregroundColor(isPast ? SR.textLo : SR.textHi)
                                    .lineLimit(1)
                                if isPast {
                                    Text("Date has passed")
                                        .font(.custom("Outfit-Regular", size: 10))
                                        .foregroundColor(SR.textLo)
                                }
                            }

                            Spacer()

                            Text(Self.dateFormatter.string(from: milestoneDate))
                                .font(.custom("Outfit-Regular", size: 11))
                                .foregroundColor(isPast ? SR.textLo.opacity(0.5) : SR.accent)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            milestone.enabled && !isPast
                                ? SR.primary.opacity(0.07)
                                : Color.white.opacity(0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    milestone.enabled && !isPast
                                        ? SR.primary.opacity(0.18)
                                        : SR.border,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPast)
                }
            }

            Text("Dates calculated from your procedure date")
                .font(.custom("Outfit-Regular", size: 10))
                .foregroundColor(SR.textLo)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, SR.bg.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .frame(height: 20)

            VStack(spacing: 10) {
                Button {
                    isScheduling = true
                    Task { @MainActor in
                        await scheduleReminders()
                        isScheduling = false
                        dismiss()
                    }
                } label: {
                    Group {
                        if isScheduling {
                            ProgressView().tint(.white)
                        } else {
                            Text(primaryButtonLabel)
                                .font(.custom("Outfit-SemiBold", size: 15))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [SR.gradA, SR.gradB],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
                .disabled(isScheduling)

                Button { dismiss() } label: {
                    Text("Maybe later")
                        .font(.custom("Outfit-Regular", size: 13))
                        .foregroundColor(SR.textLo)
                        .padding(.vertical, 6)
                }
                .disabled(isScheduling)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .background(SR.bg)
        }
    }

    private var primaryButtonLabel: String {
        if config.isSurgical {
            let count = followUpMilestones.filter(\.enabled).count
            return count == 0 ? "Done" : "Set \(count) Reminder\(count == 1 ? "" : "s")"
        }
        return reminderEnabled ? "Set Reminder" : "Done"
    }

    // MARK: - Scheduling

    private func scheduleReminders() async {
        if config.isSurgical {
            var reminders: [TreatmentReminder] = []
            for milestone in followUpMilestones where milestone.enabled {
                let date = Calendar.current.date(
                    byAdding: .day, value: milestone.daysFromProcedure, to: procedureDate
                ) ?? procedureDate
                guard date > Date() else { continue }
                let reminder = TreatmentReminder(
                    procedureName: procedureName,
                    procedureDate: procedureDate,
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
                procedureName: procedureName,
                procedureDate: procedureDate,
                reminderDate: reminderDate,
                label: "Next \(config.procedureDisplayName)",
                kind: .retreatment
            )
            await TreatmentNotificationService.shared.schedule(reminder)
            TreatmentReminderStore.shared.save(reminder)
        }
    }
}
