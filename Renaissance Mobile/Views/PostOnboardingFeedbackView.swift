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
    @Environment(\.requestReview) private var requestReview

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
                        continueButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                }
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
                Image(systemName: source.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? FeedbackUI.primary : FeedbackUI.rose)
                    .frame(width: 34, height: 34)
                    .background((isSelected ? FeedbackUI.primarySoft : FeedbackUI.roseSoft).opacity(0.9))
                    .clipShape(Circle())

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

    @MainActor
    private func triggerReviewPromptIfNeeded() async {
        guard !didTriggerReviewPrompt else { return }
        guard ReviewPromptStore.shouldRequestAutomaticReview else { return }

        didTriggerReviewPrompt = true
        ReviewPromptStore.markAutomaticReviewRequested()

        try? await Task.sleep(for: .milliseconds(700))
        requestReview()
    }
}

#Preview {
    PostOnboardingFeedbackView(onDone: {})
}
