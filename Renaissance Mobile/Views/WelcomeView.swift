//
//  WelcomeView.swift
//  Renaissance Mobile
//

import SwiftUI
import UIKit

struct WelcomeView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showSignIn = false
    @State private var showSignUp = false

    // MARK: - Loading animation state
    private enum LoadingPhase { case idle, appearing, spinning, expanding, complete }
    @State private var loadingPhase: LoadingPhase = .idle
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.4
    @State private var rotationDegrees: Double = 0
    @State private var contentOpacity: Double = 0

    var onStartConsultation: (() -> Void)?
    var onSignIn: (() -> Void)?

    var body: some View {
        ZStack {
            Color(hex: "#FAFAFF").ignoresSafeArea()

            if loadingPhase != .complete {
                Color(hex: "#6C63FF")
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            if loadingPhase != .complete {
                concentricCirclesLogo(useWhite: true)
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale)
                    .rotationEffect(.degrees(rotationDegrees))
            }

            if loadingPhase == .complete || loadingPhase == .expanding {
                VStack(spacing: 0) {
                    Spacer(minLength: 98)

                    mainContent
                        .padding(.horizontal, 36)

                    Spacer(minLength: 40)

                    footerSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 48)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(contentOpacity)
            }
        }
        .ignoresSafeArea()
        .onAppear { startLoadingAnimation() }
        .sheet(isPresented: $showSignIn) {
            SignInView(onSignIn: {
                showSignIn = false
                onSignIn?()
            })
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView(
                onSignUp: {
                    showSignUp = false
                    onSignIn?()
                },
                onSignIn: {
                    showSignUp = false
                    showSignIn = true
                }
            )
        }
    }

    // MARK: - Loading Animation

    private func startLoadingAnimation() {
        loadingPhase = .appearing
        withAnimation(.easeOut(duration: 0.55)) {
            logoOpacity = 1
            logoScale = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            loadingPhase = .spinning
            withAnimation(.linear(duration: 1.4)) {
                rotationDegrees = 720
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.15) {
            loadingPhase = .expanding
            withAnimation(.easeIn(duration: 0.35)) {
                logoScale = 2.2
                logoOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 0.45)) {
                loadingPhase = .complete
                contentOpacity = 1
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            concentricCirclesLogo()

            Text("Your aesthetic companion.")
                .font(.custom("Manrope", size: 32).weight(.heavy))
                .foregroundColor(Color(hex: "#2D2575"))
                .multilineTextAlignment(.center)
                .padding(.top, 36)

            Text("Track, ask, and remember.")
                .font(.custom("PlusJakartaSans-Regular", size: 15))
                .foregroundColor(Color(hex: "#7B6FC0"))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logo (violet palette)

    private func concentricCirclesLogo(useWhite: Bool = false) -> some View {
        let primary = useWhite ? Color.white : Color(hex: "#8B7FF0")
        let accent  = useWhite ? Color.white : Color(hex: "#6C63FF")

        return Canvas { context, size in
            let s  = size.width / 80
            let cx = size.width / 2
            let cy = size.height / 2

            var outer = Path()
            outer.addEllipse(in: CGRect(x: cx - 38*s, y: cy - 38*s, width: 76*s, height: 76*s))
            context.stroke(outer, with: .color(primary), lineWidth: 1.5)

            var middle = Path()
            middle.addEllipse(in: CGRect(x: cx - 28*s, y: cy - 28*s, width: 56*s, height: 56*s))
            context.stroke(middle, with: .color(primary), lineWidth: 1.2)

            var inner = Path()
            inner.addEllipse(in: CGRect(x: cx - 18*s, y: cy - 18*s, width: 36*s, height: 36*s))
            context.stroke(inner, with: .color(accent), lineWidth: 1.5)

            var arc = Path()
            arc.move(to: CGPoint(x: 40*s, y: 26*s))
            arc.addCurve(
                to: CGPoint(x: 54*s, y: 40*s),
                control1: CGPoint(x: 48*s, y: 26*s),
                control2: CGPoint(x: 54*s, y: 32*s)
            )
            arc.addCurve(
                to: CGPoint(x: 40*s, y: 54*s),
                control1: CGPoint(x: 54*s, y: 48*s),
                control2: CGPoint(x: 48*s, y: 54*s)
            )
            context.stroke(arc, with: .color(primary), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

            var dot = Path()
            dot.addEllipse(in: CGRect(x: cx - 4*s, y: cy - 4*s, width: 8*s, height: 8*s))
            context.fill(dot, with: .color(accent))
        }
        .frame(width: 110, height: 110)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 0) {
            // Apple
            Button {
                Task {
                    await authViewModel.signInWithApple()
                    if authViewModel.isAuthenticated { onSignIn?() }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Continue with Apple")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 16).weight(.bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(hex: "#2D2575"))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .disabled(authViewModel.isLoading)

            // Google
            Button {
                Task {
                    guard let vc = getRootViewController() else {
                        return
                    }
                    await authViewModel.signInWithGoogle(presentingViewController: vc)
                    if authViewModel.isAuthenticated { onSignIn?() }
                }
            } label: {
                HStack(spacing: 12) {
                    googleColorIcon
                    Text("Continue with Google")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 16).weight(.bold))
                        .foregroundColor(Color(hex: "#2D2575"))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color(hex: "#D4CCFF"), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .padding(.top, 12)
            .disabled(authViewModel.isLoading)

            // Divider
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(hex: "#D4CCFF"))
                Text("or")
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .foregroundColor(Color(hex: "#7B6FC0"))
                    .padding(.horizontal, 14)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(hex: "#D4CCFF"))
            }
            .padding(.vertical, 18)

            // Email
            Button { showSignIn = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "envelope")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#6C63FF"))
                    Text("Continue with email")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 16).weight(.bold))
                        .foregroundColor(Color(hex: "#6C63FF"))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(hex: "#EAE7FF"))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .disabled(authViewModel.isLoading)

            legalFootnote
                .padding(.top, 24)
        }
    }

    private var legalFootnote: some View {
        Text(legalAttributedString)
            .font(.custom("PlusJakartaSans-Regular", size: 13))
            .foregroundColor(Color(hex: "#7B6FC0"))
            .tint(Color(hex: "#6C63FF"))
            .multilineTextAlignment(.center)
    }

    private var legalAttributedString: AttributedString {
        let terms   = AppConfig.termsOfUseURL.absoluteString
        let privacy = AppConfig.privacyPolicyURL.absoluteString
        let md = "By continuing, you agree to our [Terms of Use](\(terms)) and [Privacy Policy](\(privacy))"
        return (try? AttributedString(markdown: md))
            ?? AttributedString("By continuing, you agree to our Terms of Use and Privacy Policy")
    }

    // MARK: - Google icon

    private var googleColorIcon: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let r  = size.width * 0.36
            let lw = size.width * 0.22

            let blue   = Color(red: 0.259, green: 0.522, blue: 0.957)
            let red    = Color(red: 0.918, green: 0.263, blue: 0.208)
            let yellow = Color(red: 0.984, green: 0.737, blue: 0.020)
            let green  = Color(red: 0.204, green: 0.659, blue: 0.325)

            let segments: [(Color, Double, Double)] = [
                (blue,   -15,  75),
                (red,     75, 195),
                (yellow, 195, 255),
                (green,  255, 345)
            ]
            for (color, start, end) in segments {
                var arc = Path()
                arc.addArc(
                    center: CGPoint(x: cx, y: cy),
                    radius: r,
                    startAngle: .degrees(start),
                    endAngle: .degrees(end),
                    clockwise: false
                )
                context.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .butt))
            }

            let half = lw * 0.3
            var bar = Path()
            bar.addRect(CGRect(x: cx, y: cy - half, width: r + lw * 0.5, height: half * 2))
            context.fill(bar, with: .color(blue))
        }
        .frame(width: 22, height: 22)
    }

    // MARK: - Root VC helper for Google sign-in

    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let root = window.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

#Preview {
    WelcomeView()
        .environment(AuthViewModel())
}
