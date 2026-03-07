//
//  PhotoConsentBannerView.swift
//  Renaissance Mobile
//

import SwiftUI

struct PhotoConsentBannerView: View {
    let onGrant: () -> Void
    let onDeny: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onDeny() }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {

                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Theme.Brand.dustyRose)
                                Text("Photo Journal Consent")
                                    .font(.system(size: 20, weight: .semibold, design: .serif))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                            Text("Before you start tracking your recovery, please review how we handle your photos.")
                                .font(Theme.Typography.heroSubtitle)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }

                        Divider().overlay(Theme.Brand.softBlush)

                        ConsentPoint(
                            icon: "iphone.and.arrow.forward",
                            title: "What we collect",
                            text: "Photos you take or upload, along with the procedure name and recovery day you provide."
                        )
                        ConsentPoint(
                            icon: "lock.shield.fill",
                            title: "How it's stored",
                            text: "Photos are stored securely in your private account and are never shared with other users, third parties, or advertisers."
                        )
                        ConsentPoint(
                            icon: "eye.slash.fill",
                            title: "AI analysis",
                            text: "When you request analysis, your photo is sent to Google Gemini Vision for recovery metrics (swelling, bruising, redness). The image is not retained by Google beyond the API call."
                        )
                        ConsentPoint(
                            icon: "hand.raised.fill",
                            title: "Your control",
                            text: "You can delete any photo or journal entry at any time. Deletion permanently removes the photo from our servers."
                        )
                        ConsentPoint(
                            icon: "cross.case.fill",
                            title: "Medical disclaimer",
                            text: "AI recovery analysis is for personal tracking only and does not constitute medical advice. Always follow your provider's instructions and contact them with any concerns."
                        )

                        VStack(spacing: Theme.Spacing.sm) {
                            Button(action: onGrant) {
                                Text("I Understand & Agree")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Theme.Brand.mauveBerry)
                                    .clipShape(Capsule())
                            }
                            Button(action: onDeny) {
                                Text("Not Now")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }
                        .padding(.top, Theme.Spacing.sm)
                    }
                    .padding(Theme.Spacing.xl)
                }
            }
            .background(RoundedRectangle(cornerRadius: 24).fill(Theme.Brand.cream))
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, 24)
        }
    }
}

private struct ConsentPoint: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Theme.Brand.softBlush)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Brand.mauveBerry)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
