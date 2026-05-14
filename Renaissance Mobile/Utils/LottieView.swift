#if canImport(Lottie)
import Lottie
import SwiftUI

struct LottieView: UIViewRepresentable {
    let name: String
    var loop: Bool = true

    private var resolvedLoopMode: LottieLoopMode { loop ? .loop : .playOnce }

    func makeUIView(context: Context) -> LottieAnimationView {
        let av = LottieAnimationView()
        av.loopMode = resolvedLoopMode
        av.contentMode = .scaleAspectFit
        av.backgroundBehavior = .pauseAndRestore
        // Allow SwiftUI .frame() to control size instead of the animation's intrinsic size
        av.setContentHuggingPriority(.defaultLow, for: .vertical)
        av.setContentHuggingPriority(.defaultLow, for: .horizontal)
        av.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        av.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        guard let url = Bundle.main.url(forResource: name, withExtension: "lottie") else {
            print("[LottieView] ❌ '\(name).lottie' not found in bundle")
            return av
        }

        print("[LottieView] ✅ Found at \(url.lastPathComponent)")

        Task { @MainActor in
            do {
                let file = try await DotLottieFile.loadedFrom(url: url)
                av.loadAnimation(from: file)
                av.loopMode = resolvedLoopMode
                av.play()
                print("[LottieView] ✅ Playing")
            } catch {
                print("[LottieView] ❌ Load failed: \(error)")
            }
        }

        return av
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {}
}

#else
import SwiftUI

struct LottieView: View {
    let name: String
    var loop: Bool = true
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "#8B7FF0").opacity(0.35), lineWidth: 1.5)
                .frame(width: 160, height: 160)
            Circle()
                .stroke(Color(hex: "#8B7FF0").opacity(0.55), lineWidth: 1.2)
                .frame(width: 116, height: 116)
            Circle()
                .stroke(Color(hex: "#6C63FF"), lineWidth: 1.5)
                .frame(width: 74, height: 74)
            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(Color(hex: "#8B7FF0").opacity(0.65), lineWidth: 1.2)
                .frame(width: 116, height: 116)
                .rotationEffect(.degrees(90))
            Circle()
                .fill(Color(hex: "#6C63FF"))
                .frame(width: 11, height: 11)
        }
        .scaleEffect(pulse ? 1.07 : 0.97)
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}
#endif
