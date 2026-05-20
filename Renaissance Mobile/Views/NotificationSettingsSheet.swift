//
//  NotificationSettingsSheet.swift
//  Renaissance Mobile
//

import SwiftUI

private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

struct NotificationSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("rena.notificationMode")    private var storedMode    = NotificationMode.daily.rawValue
    @AppStorage("rena.notificationHour")    private var storedHour    = 9
    @AppStorage("rena.notificationMinute")  private var storedMinute  = 0
    @AppStorage("rena.notificationWeekday") private var storedWeekday = 2 // Monday (Calendar: 1=Sun … 7=Sat)

    @State private var isSaving = false

    private let profileService = UserProfileService(supabase: supabase)

    private var selectedMode: NotificationMode {
        NotificationMode(rawValue: storedMode) ?? .daily
    }

    // Date binding for the compact time picker
    private var timePick: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents(); c.hour = storedHour; c.minute = storedMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                storedHour   = c.hour   ?? 9
                storedMinute = c.minute ?? 0
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color(hex: "#D4CCFF"))
                .frame(width: 36, height: 4)
                .padding(.top, 14)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Mascot + header
                    VStack(spacing: 6) {
                        LottieView(name: "cute-mascot", loop: true)
                            .frame(width: 100, height: 100)

                        Text("Notifications")
                            .font(.custom("Manrope", size: 22))
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "#2D2575"))

                        Text("Choose how often Rena reminds you to check in.")
                            .font(.custom("PlusJakartaSans-Regular", size: 14))
                            .foregroundColor(Color(hex: "#7B6FC0"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)

                    // Option rows
                    VStack(spacing: 14) {
                        modeRow(.off)
                        modeRow(.daily)
                        modeRow(.weekly)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 36)
                }
            }

            // Save button
            Button { save() } label: {
                Group {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: "#6C63FF"))
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#6C63FF").opacity(0.3), radius: 10, y: 4)
            }
            .disabled(isSaving)
            .padding(.horizontal, 22)
            .padding(.bottom, 36)
        }
        .background(Color(hex: "#F8F8FF").ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#7B6FC0"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "#EAE7FF"))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            .padding(.trailing, 22)
        }
    }

    // MARK: - Mode row (with inline expansion)

    @ViewBuilder
    private func modeRow(_ mode: NotificationMode) -> some View {
        let isSelected = selectedMode == mode

        VStack(spacing: 0) {
            // Row header button
            Button {
                guard !isSaving else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    storedMode = mode.rawValue
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(isSelected ? Color(hex: "#6C63FF") : Color(hex: "#EAE7FF"))
                            .frame(width: 46, height: 46)
                        Image(systemName: mode.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isSelected ? .white : Color(hex: "#6C63FF"))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(mode.label)
                            .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                            .foregroundColor(Color(hex: "#2D2575"))
                        Text(mode.subtitle)
                            .font(.custom("PlusJakartaSans-Regular", size: 12))
                            .foregroundColor(Color(hex: "#7B6FC0"))
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color(hex: "#6C63FF") : Color(hex: "#D4CCFF"), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Circle()
                                .fill(Color(hex: "#6C63FF"))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // Inline expansion for daily/weekly
            if isSelected, mode != .off {
                VStack(spacing: 16) {
                    Divider()
                        .background(Color(hex: "#D4CCFF").opacity(0.5))
                        .padding(.horizontal, 16)

                    if mode == .weekly {
                        weekdayPicker
                            .padding(.horizontal, 16)
                    }

                    timePicker
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isSelected ? Color(hex: "#EAE7FF") : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isSelected ? Color(hex: "#6C63FF").opacity(0.28) : Color(hex: "#D4CCFF").opacity(0.55),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .shadow(color: Color(hex: "#6C63FF").opacity(0.06), radius: 8, x: 0, y: 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }

    // MARK: - Weekday picker

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Day")
                .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                .foregroundColor(Color(hex: "#7B6FC0"))

            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { day in
                    let isChosen = storedWeekday == day
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { storedWeekday = day }
                    } label: {
                        Text(dayNames[day - 1])
                            .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                            .foregroundColor(isChosen ? .white : Color(hex: "#7B6FC0"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isChosen ? Color(hex: "#6C63FF") : Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    isChosen ? Color.clear : Color(hex: "#D4CCFF").opacity(0.6),
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Time picker

    private var timePicker: some View {
        HStack {
            Text("Time")
                .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                .foregroundColor(Color(hex: "#7B6FC0"))
            Spacer()
            DatePicker("", selection: timePick, displayedComponents: [.hourAndMinute])
                .labelsHidden()
                .tint(Color(hex: "#6C63FF"))
        }
    }

    // MARK: - Save

    private func save() {
        isSaving = true
        Task {
            await NotificationModeService.shared.apply(
                selectedMode,
                hour: storedHour,
                minute: storedMinute,
                weekday: storedWeekday,
                profileService: profileService
            )
            isSaving = false
            dismiss()
        }
    }
}
