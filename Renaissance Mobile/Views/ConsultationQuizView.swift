//
//  ConsultationQuizView.swift
//  Renaissance Mobile
//
//  Created by Claude on 1/24/26.
//

import SwiftUI

struct ConsultationQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var birthday: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()

    var onContinue: ((Date) -> Void)?

    private var age: Int {
        Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
    }

    private var isAdult: Bool {
        age >= 18
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundWelcome
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress indicator
                    progressBar
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    Spacer()

                    // Main content
                    VStack(spacing: 32) {
                        // Question
                        VStack(spacing: 12) {
                            Text("When is your birthday?")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Theme.Colors.textWelcomePrimary)
                                .multilineTextAlignment(.center)

                            Text("This helps us personalize your consultation experience.")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.Colors.textWelcomeSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)

                        // Date picker
                        DatePicker(
                            "",
                            selection: $birthday,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxHeight: 200)
                        .padding(.horizontal, 24)
                        .colorScheme(.light)
                        .tint(.black)

                        // Age display
                        VStack(spacing: 4) {
                            if age > 0 {
                                Text("Age: \(age) years old")
                                    .font(.system(size: 14))
                                    .foregroundColor(isAdult ? Theme.Colors.textWelcomeSecondary : .red)
                            }
                            Text("Must be at least 18 years old to proceed")
                                .font(.system(size: 12))
                                .foregroundColor(isAdult ? Theme.Colors.textWelcomeSecondary : .red)
                        }
                    }

                    Spacer()

                    // Continue button
                    Button(action: {
                        onContinue?(birthday)
                    }) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isAdult ? Color.black : Color.gray.opacity(0.4))
                            .cornerRadius(Theme.CornerRadius.medium)
                    }
                    .disabled(!isAdult)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Consultation")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Colors.textWelcomePrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.Colors.textWelcomePrimary)
                    }
                }
            }
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)

                // Progress (step 1 of multiple steps)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.primaryWelcome)
                    .frame(width: geometry.size.width * 0.25, height: 4)
            }
        }
        .frame(height: 4)
    }
}

#Preview {
    ConsultationQuizView()
}
