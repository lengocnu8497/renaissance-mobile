//
//  WelcomeView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI

struct WelcomeView: View {
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
            // Background — dusty rose during animation, cream after
            Theme.Colors.backgroundWelcome
                .ignoresSafeArea()

            if loadingPhase != .complete {
                Color(red: 196/255, green: 146/255, blue: 154/255)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Centered loading logo — visible during animation phases
            if loadingPhase != .complete {
                concentricCirclesLogo(useWhite: true)
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale)
                    .rotationEffect(.degrees(rotationDegrees))
            }

            // Full content — fades in after animation
            if loadingPhase == .complete || loadingPhase == .expanding {
                VStack(spacing: 0) {
                    Spacer(minLength: 72)

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
        // Phase 1: Logo appears
        loadingPhase = .appearing
        withAnimation(.easeOut(duration: 0.55)) {
            logoOpacity = 1
            logoScale = 1
        }

        // Phase 2: Spin (2 full rotations)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            loadingPhase = .spinning
            withAnimation(.linear(duration: 1.4)) {
                rotationDegrees = 720
            }
        }

        // Phase 3: Expand + fade out logo
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.15) {
            loadingPhase = .expanding
            withAnimation(.easeIn(duration: 0.35)) {
                logoScale = 2.2
                logoOpacity = 0
            }
        }

        // Phase 4: Full content fades in, background transitions to cream
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
                .padding(.top, 2)

            VStack(spacing: 0) {
                Text("Rena Aesthetic")
                    .font(.system(size: 30, weight: .light, design: .serif))
                    .foregroundColor(Color(red: 61/255, green: 43/255, blue: 46/255))
                    .padding(.top, 30)

                Text("LAB")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 196/255, green: 146/255, blue: 154/255))
                    .kerning(4.1)
                    .padding(.top, 8)
            }

            VStack(spacing: 0) {
                Text("Your aesthetic companion.")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundColor(Color(red: 54/255, green: 71/255, blue: 60/255))
                    .multilineTextAlignment(.center)
                    .lineSpacing(0)
                    .padding(.top, 64)
                    .frame(maxWidth: 280)

                Text("Track, ask, and remember.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(red: 122/255, green: 130/255, blue: 120/255))
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .padding(.top, 20)
                    .frame(maxWidth: 285)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logo
    private func concentricCirclesLogo(useWhite: Bool = false) -> some View {
        let dustyRose = useWhite ? Color.white : Color(red: 196/255, green: 146/255, blue: 154/255)
        let mauveberry = useWhite ? Color.white : Color(red: 142/255, green: 76/255, blue: 92/255)

        return Canvas { context, size in
            // Scale all SVG coordinates (base viewBox: 80×80, center: 40,40)
            let s = size.width / 80
            let cx = size.width / 2
            let cy = size.height / 2

            // Outer circle (r=38)
            var outer = Path()
            outer.addEllipse(in: CGRect(x: cx - 38*s, y: cy - 38*s, width: 76*s, height: 76*s))
            context.stroke(outer, with: .color(dustyRose), lineWidth: 1.5)

            // Middle circle (r=28)
            var middle = Path()
            middle.addEllipse(in: CGRect(x: cx - 28*s, y: cy - 28*s, width: 56*s, height: 56*s))
            context.stroke(middle, with: .color(dustyRose), lineWidth: 1.2)

            // Inner circle (r=18) — Mauve Berry
            var inner = Path()
            inner.addEllipse(in: CGRect(x: cx - 18*s, y: cy - 18*s, width: 36*s, height: 36*s))
            context.stroke(inner, with: .color(mauveberry), lineWidth: 1.5)

            // Right-side arc: M40 26 C48 26, 54 32, 54 40 C54 48, 48 54, 40 54
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
            context.stroke(arc, with: .color(dustyRose), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

            // Center dot (r=4)
            var dot = Path()
            dot.addEllipse(in: CGRect(x: cx - 4*s, y: cy - 4*s, width: 8*s, height: 8*s))
            context.fill(dot, with: .color(dustyRose))
        }
        .frame(width: 110, height: 110)
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 0) {
            Button(action: {
                showSignUp = true
            }) {
                Text("Start My Consultation")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(red: 84/255, green: 99/255, blue: 89/255))
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }

            Button(action: {
                showSignUp = true
            }) {
                Text("Create Account")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 61/255, green: 43/255, blue: 46/255))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color(red: 196/255, green: 146/255, blue: 154/255).opacity(0.3), lineWidth: 1)
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.top, 12)

            Button(action: {
                showSignIn = true
            }) {
                Text("Sign In")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(red: 122/255, green: 130/255, blue: 120/255))
                    .underline()
            }
            .padding(.top, 16)
        }
    }
}

#Preview {
    WelcomeView()
}
