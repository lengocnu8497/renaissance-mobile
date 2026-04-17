//
//  PostOnboardingFeedbackView.swift
//  Renaissance Mobile
//

import SwiftUI
import StoreKit

private enum FeedbackUI {
    static let background = Color(hex: "#F6F7F2")
    static let card = Color.white
    static let primary = Color(hex: "#516048")
    static let primarySoft = Color(hex: "#D9E3CE")
    static let rose = Color(hex: "#B07B7A")
    static let roseSoft = Color(hex: "#F1DDDA")
    static let text = Color(hex: "#1F261D")
    static let muted = Color(hex: "#687064")
}

struct PostOnboardingFeedbackView: View {
    @State private var selectedSource = OnboardingStore.pendingAcquisitionSource
    @State private var isSubmitting = false
    @State private var didTriggerReviewPrompt = false

    let onDone: () -> Void

    private let profileService = UserProfileService(supabase: supabase)

    var body: some View {
        NavigationStack {
            ZStack {
                FeedbackUI.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard
                        attributionCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                    .padding(.bottom, 112)
                }
            }
            .safeAreaInset(edge: .bottom) {
                blendedContinueCTA
            }
            .interactiveDismissDisabled(isSubmitting)
            .task {
                await triggerReviewPromptIfNeeded()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Welcome to Renaissance")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(FeedbackUI.text)

            Text("Apple may show a quick rating prompt while you’re here. One last thing before we drop you into the app.")
                .font(.system(size: 15))
                .foregroundColor(FeedbackUI.muted)
                .lineSpacing(4)

            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundColor(FeedbackUI.rose)
                }
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FeedbackUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var attributionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Where did you hear about us?")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(FeedbackUI.text)

            Text("This helps us understand which channels are actually working.")
                .font(.system(size: 14))
                .foregroundColor(FeedbackUI.muted)

            VStack(spacing: 10) {
                ForEach(AcquisitionSource.allCases) { source in
                    sourceRow(for: source)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FeedbackUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func sourceRow(for source: AcquisitionSource) -> some View {
        let isSelected = selectedSource == source

        return Button {
            selectedSource = source
        } label: {
            HStack(spacing: 12) {
                AcquisitionSourceIcon(source: source, isSelected: isSelected)

                Text(source.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(FeedbackUI.text)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? FeedbackUI.primary : FeedbackUI.muted.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(isSelected ? FeedbackUI.primarySoft.opacity(0.55) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var continueButton: some View {
        Button {
            Task {
                guard let selectedSource else { return }
                isSubmitting = true
                OnboardingStore.savePendingAcquisitionSource(selectedSource)
                await OnboardingStore.syncAttributionIfNeeded(using: profileService)
                OnboardingStore.completePostOnboardingFeedback()
                isSubmitting = false
                onDone()
            }
        } label: {
            Group {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(selectedSource == nil ? FeedbackUI.primary.opacity(0.35) : FeedbackUI.primary)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .disabled(selectedSource == nil || isSubmitting)
    }

    private var blendedContinueCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.clear, FeedbackUI.background.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 24)

            continueButton
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(FeedbackUI.background.opacity(0.96))
        }
    }

    @MainActor
    private func triggerReviewPromptIfNeeded() async {
        guard !didTriggerReviewPrompt else { return }
        guard ReviewPromptStore.shouldRequestAutomaticReview else { return }

        let outcome = await ReviewRequestHelper.requestWhenReady(
            initialDelayMilliseconds: 700
        )
        guard outcome == .requested else { return }

        didTriggerReviewPrompt = true
        ReviewPromptStore.markAutomaticReviewRequested()
    }
}

private struct AcquisitionSourceIcon: View {
    let source: AcquisitionSource
    let isSelected: Bool

    var body: some View {
        ZStack {
            backgroundShape

            switch source {
            case .instagram:
                instagramGlyph
            case .tiktok:
                tikTokGlyph
            case .googleSearch:
                Text("G")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(googleGradient)
            case .friendOrFamily:
                Image(systemName: "person.2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconForeground)
            case .doctorOrClinic:
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconForeground)
            case .appStoreSearch:
                Image(systemName: "apple.logo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            case .pressOrBlog:
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconForeground)
            case .other:
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconForeground)
            }
        }
        .frame(width: 36, height: 36)
    }

    @ViewBuilder
    private var backgroundShape: some View {
        switch source {
        case .instagram:
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#FEDA75"),
                            Color(hex: "#FA7E1E"),
                            Color(hex: "#D62976"),
                            Color(hex: "#962FBF"),
                            Color(hex: "#4F5BD5"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case .tiktok:
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.black)
        case .googleSearch:
            Circle()
                .fill(Color.white)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
        case .appStoreSearch:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: "#1677F2"))
        default:
            Circle()
                .fill((isSelected ? FeedbackUI.primarySoft : FeedbackUI.roseSoft).opacity(0.95))
        }
    }

    private var iconForeground: Color {
        isSelected ? FeedbackUI.primary : FeedbackUI.rose
    }

    private var googleGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#4285F4"),
                Color(hex: "#34A853"),
                Color(hex: "#FBBC05"),
                Color(hex: "#EA4335"),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var instagramGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 1.9)
                .frame(width: 17, height: 17)

            Circle()
                .strokeBorder(Color.white, lineWidth: 1.9)
                .frame(width: 7, height: 7)

            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
                .offset(x: 5, y: -5)
        }
    }

    private var tikTokGlyph: some View {
        ZStack {
            Image(systemName: "music.note")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "#25F4EE"))
                .offset(x: -1.2, y: 0.8)

            Image(systemName: "music.note")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "#FE2C55"))
                .offset(x: 1.2, y: -0.8)

            Image(systemName: "music.note")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    PostOnboardingFeedbackView(onDone: {})
}
