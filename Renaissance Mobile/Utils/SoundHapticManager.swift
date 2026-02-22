//
//  SoundHapticManager.swift
//  Renaissance Mobile
//

import AudioToolbox
import UIKit
import SwiftUI

// MARK: - Sound & Haptic Manager

final class SoundHapticManager {
    static let shared = SoundHapticManager()
    private init() {}

    /// Short tick + light haptic — plays on every button press
    func playButtonTick() {
        AudioServicesPlaySystemSound(1123) // soft keyboard click
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Outgoing swoosh — plays when user sends a message
    func playSendWoosh() {
        AudioServicesPlaySystemSound(1004) // iMessage sent whoosh
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Incoming swoosh — plays when assistant reply arrives
    func playReplyWoosh() {
        AudioServicesPlaySystemSound(1032) // glass ping
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Global Button Style

struct TickButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    SoundHapticManager.shared.playButtonTick()
                }
            }
    }
}
