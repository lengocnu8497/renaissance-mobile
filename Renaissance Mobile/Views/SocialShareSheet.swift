//
//  SocialShareSheet.swift
//  Renaissance Mobile
//
//  Bottom sheet for sharing recovery insights to Instagram, TikTok, Facebook,
//  and the system share sheet.
//
//  Instagram: deep-links directly to Stories via URL scheme + UIPasteboard.
//  TikTok / Facebook: present UIActivityViewController (both apps register
//  share extensions that appear in the system sheet when installed).
//

import SwiftUI

// MARK: - Social Share Sheet

struct SocialShareSheet: View {
    let insights: RecoveryInsights
    @Environment(\.dismiss) private var dismiss

    @State private var renderedImage: UIImage? = nil
    @State private var isRendering = true
    @State private var showSystemShare = false
    @State private var showInstagramUnavailable = false

    private var shareCaption: String {
        var text = "My recovery insight from Rena Aesthetic Lab ✦\n\n\"\(insights.summary)\""
        if let steps = insights.nextSteps {
            text += "\n\nNext steps: \(steps)"
        }
        let tag = insights.procedureName
            .components(separatedBy: .whitespaces)
            .map { $0.capitalized }
            .joined()
        text += "\n\n#RenaAestheticLab #RecoveryJourney #\(tag)Recovery #PostOpRecovery"
        return text
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            header
            platforms
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#FFF8F6"))
        .task { await renderImage() }
        .sheet(isPresented: $showSystemShare) {
            if let img = renderedImage {
                ActivityViewController(items: [img, shareCaption])
            }
        }
        .alert("Instagram Not Installed", isPresented: $showInstagramUnavailable) {
            Button("Share via System") { showSystemShare = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Install Instagram and try again, or share via the system sheet.")
        }
    }

    // MARK: - Subviews

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(hex: "#C4929A").opacity(0.3))
            .frame(width: 40, height: 5)
            .padding(.top, 14)
            .padding(.bottom, 22)
    }

    private var header: some View {
        VStack(spacing: 5) {
            Text("Share Your Progress")
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundColor(Color(hex: "#3D2B2E"))
            Text("Inspire others with your healing journey")
                .font(.custom("Outfit-Regular", size: 13))
                .foregroundColor(Color(hex: "#B8A9AB"))
        }
        .padding(.bottom, 30)
    }

    private var platforms: some View {
        HStack(spacing: 0) {
            Spacer()
            PlatformButton(
                label: "Instagram",
                systemIcon: "camera.fill",
                iconColor: .white,
                background: AnyShapeStyle(
                    LinearGradient(
                        colors: [Color(hex: "#F58529"), Color(hex: "#DD2A7B"), Color(hex: "#8134AF")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                ),
                isLoading: isRendering,
                action: shareToInstagram
            )
            Spacer()
            PlatformButton(
                label: "TikTok",
                systemIcon: "music.note",
                iconColor: .white,
                background: AnyShapeStyle(Color.black),
                isLoading: isRendering,
                action: { showSystemShare = true }
            )
            Spacer()
            PlatformButton(
                label: "Facebook",
                systemIcon: "person.2.fill",
                iconColor: .white,
                background: AnyShapeStyle(Color(hex: "#1877F2")),
                isLoading: isRendering,
                action: { showSystemShare = true }
            )
            Spacer()
            PlatformButton(
                label: "More",
                systemIcon: "square.and.arrow.up",
                iconColor: .white,
                background: AnyShapeStyle(Color(hex: "#8E4C5C")),
                isLoading: false,
                action: { showSystemShare = true }
            )
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
    }

    // MARK: - Instagram Stories

    private func shareToInstagram() {
        guard let image = renderedImage else { return }
        let urlString = "instagram-stories://share?source_application=\(Bundle.main.bundleIdentifier ?? "")"
        guard let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else {
            showInstagramUnavailable = true
            return
        }
        guard let data = image.pngData() else { return }
        UIPasteboard.general.setItems(
            [["com.instagram.sharedSticker.backgroundImage": data]],
            options: [.expirationDate: Date().addingTimeInterval(300)]
        )
        UIApplication.shared.open(url)
    }

    // MARK: - Image Rendering

    @MainActor
    private func renderImage() async {
        isRendering = true
        let card = InsightsShareCard(insights: insights)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderedImage = renderer.uiImage
        isRendering = false
    }
}

// MARK: - Platform Button

private struct PlatformButton: View {
    let label: String
    let systemIcon: String
    let iconColor: Color
    let background: AnyShapeStyle
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(background)
                        .frame(width: 56, height: 56)
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: systemIcon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(iconColor)
                    }
                }
                Text(label)
                    .font(.custom("Outfit-Regular", size: 11))
                    .foregroundColor(Color(hex: "#6B4F53"))
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Insights Share Card (rendered to UIImage)

private struct InsightsShareCard: View {
    let insights: RecoveryInsights

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo mark + app name
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 32, height: 32)
                    // Brand logo — concentric circles (matches app icon mark)
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.40), lineWidth: 1.2)
                            .frame(width: 16, height: 16)
                        Circle()
                            .stroke(Color.white.opacity(0.65), lineWidth: 1.2)
                            .frame(width: 11, height: 11)
                        Circle()
                            .stroke(Color.white.opacity(0.90), lineWidth: 1.2)
                            .frame(width: 6.4, height: 6.4)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 2.8, height: 2.8)
                    }
                }
                Text("Rena Aesthetic Lab")
                    .font(.custom("Outfit-SemiBold", size: 13))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.bottom, 36)

            // Label
            Text("RECOVERY INSIGHT")
                .font(.custom("Outfit-Bold", size: 10))
                .kerning(2)
                .foregroundColor(.white.opacity(0.55))
                .padding(.bottom, 12)

            // Summary quote
            Text("\u{201C}\(insights.summary)\u{201D}")
                .font(.system(size: 22, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(.white)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 28)

            // Trend + procedure
            HStack(spacing: 10) {
                Label(insights.trend.label, systemImage: insights.trend.systemImage)
                    .font(.custom("Outfit-SemiBold", size: 11))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.8))

                Text(insights.procedureName)
                    .font(.custom("Outfit-Regular", size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 32)

            // Next steps (if present)
            if let steps = insights.nextSteps {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEXT STEPS")
                        .font(.custom("Outfit-Bold", size: 9))
                        .kerning(1.5)
                        .foregroundColor(.white.opacity(0.5))
                    Text(steps)
                        .font(.custom("Outfit-Regular", size: 13))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(3)
                        .lineLimit(3)
                }
                .padding(14)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
                .padding(.bottom, 32)
            }

            // Footer — always at the bottom of content, no Spacer needed
            HStack {
                Text("Track your recovery at renaesthetic.com")
                    .font(.custom("Outfit-Regular", size: 10))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("✦")
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(32)
        // Fix only the width; height grows with content so nothing overflows
        .frame(width: 375)
        .background(
            LinearGradient(
                colors: [Color(hex: "#3D1A26"), Color(hex: "#6B3346"), Color(hex: "#B76E79")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .bottomTrailing) {
            // Decorative concentric circle watermark — bottom-right corner
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 1.5)
                    .frame(width: 300, height: 300)
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1.5)
                    .frame(width: 200, height: 200)
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                    .frame(width: 120, height: 120)
            }
            .offset(x: 80, y: 80)
            .allowsHitTesting(false)
        }
    }
}
