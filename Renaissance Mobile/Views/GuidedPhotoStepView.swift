//
//  GuidedPhotoStepView.swift
//  Renaissance Mobile
//
//  Step-by-step angle carousel shown when a user begins a weekly check-in.
//  Walks through each PhotoAnglePrompt in order, then hands off to AddJournalEntryView
//  via onBeginEntry callback.
//

import SwiftUI

struct GuidedPhotoStepView: View {
    let guide: WeeklyPhotoGuide
    let onBeginEntry: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    private let gradA  = Color(hex: "#6B3346")
    private let gradB  = Color(hex: "#B76E79")
    private let accent = Color(hex: "#C4929A")
    private let textHi = Color(hex: "#3D2B2E")
    private let textLo = Color(hex: "#B8A9AB")
    private let bg     = Color(hex: "#FFF8F6")

    private var currentPrompt: PhotoAnglePrompt { guide.angles[step] }
    private var isLast: Bool { step == guide.angles.count - 1 }
    private var isFirst: Bool { step == 0 }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Spacer()

                // Week pill
                weekPill
                    .padding(.bottom, 28)

                // Large angle icon
                angleIcon
                    .padding(.bottom, 22)

                // Angle name
                Text(currentPrompt.angle.displayName)
                    .font(.system(size: 26, weight: .medium, design: .serif))
                    .foregroundColor(textHi)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)

                // Instruction
                Text(currentPrompt.instruction)
                    .font(.custom("Outfit-Regular", size: 15))
                    .foregroundColor(textLo)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)

                Spacer()

                // Progress dots
                progressDots
                    .padding(.bottom, 28)

                // Navigation buttons
                navButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 44)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textHi)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(accent.opacity(0.2), lineWidth: 1))
            }
            Spacer()
            Text("Step \(step + 1) of \(guide.angles.count)")
                .font(.custom("Outfit-Regular", size: 12))
                .foregroundColor(textLo)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Week Pill

    private var weekPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "camera.fill")
                .font(.system(size: 9, weight: .semibold))
            Text("WEEK \(guide.weekNumber) CHECK-IN")
                .font(.custom("Outfit-SemiBold", size: 10))
                .kerning(0.8)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            LinearGradient(colors: [gradA, gradB], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(Capsule())
    }

    // MARK: - Angle Icon

    private var angleIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [gradA.opacity(0.12), gradB.opacity(0.12)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 130, height: 130)

            Circle()
                .stroke(
                    LinearGradient(colors: [gradA, gradB], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 2
                )
                .frame(width: 130, height: 130)

            Image(systemName: currentPrompt.angle.systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(
                    LinearGradient(colors: [gradA, gradB], startPoint: .top, endPoint: .bottom)
                )
        }
        .id(step) // force re-render on step change
        .transition(.asymmetric(
            insertion: .scale(scale: 0.92).combined(with: .opacity),
            removal:   .scale(scale: 1.06).combined(with: .opacity)
        ))
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<guide.angles.count, id: \.self) { i in
                Capsule()
                    .fill(i == step
                          ? LinearGradient(colors: [gradA, gradB], startPoint: .leading, endPoint: .trailing)
                          : LinearGradient(colors: [accent.opacity(0.25), accent.opacity(0.25)], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: i == step ? 20 : 7, height: 7)
                    .animation(.spring(duration: 0.3), value: step)
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navButtons: some View {
        HStack(spacing: 12) {
            if !isFirst {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textHi)
                        .frame(width: 50, height: 50)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(accent.opacity(0.2), lineWidth: 1))
                        .shadow(color: Color(hex: "#8E4C5C").opacity(0.07), radius: 6, x: 0, y: 2)
                }
            }

            if isLast {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onBeginEntry()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Begin Journal Entry")
                            .font(.custom("Outfit-SemiBold", size: 14))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [gradA, gradB], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: gradA.opacity(0.28), radius: 12, x: 0, y: 6)
                }
            } else {
                Button {
                    withAnimation { step += 1 }
                } label: {
                    HStack(spacing: 8) {
                        Text("Next")
                            .font(.custom("Outfit-SemiBold", size: 14))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [gradA, gradB], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: gradA.opacity(0.28), radius: 12, x: 0, y: 6)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let guide = PhotoAngleGuideService.guide(for: "Rhinoplasty", week: 1)
    GuidedPhotoStepView(guide: guide, onBeginEntry: {})
}
