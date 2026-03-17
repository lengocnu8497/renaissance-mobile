//
//  HeroCardView.swift
//  Renaissance Mobile
//

import SwiftUI

struct HeroCardView: View {
    let title: String
    let subtitle: String
    let imageName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Featured")
                .font(.custom("Outfit-Regular", size: 9))
                .tracking(3)
                .textCase(.uppercase)
                .foregroundColor(Color.white.opacity(0.55))
                .padding(.bottom, 5)

            Text(title)
                .font(.system(size: 26, weight: .medium, design: .serif))
                .foregroundColor(.white)
                .lineSpacing(2)
                .padding(.bottom, 5)

            Text(subtitle)
                .font(.custom("Outfit-Light", size: 12))
                .foregroundColor(Color.white.opacity(0.68))
                .padding(.bottom, 16)

            // Discover Now pill
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "arrow.forward")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                    )
                Text("Discover Now")
                    .font(.custom("Outfit-SemiBold", size: 11))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 7)
            .padding(.leading, 9)
            .padding(.trailing, 14)
            .background(Color.white.opacity(0.16))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.24), lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: [Color(hex: "#6B3346"), Color(hex: "#8E4C5C"), Color(hex: "#B76E79")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            ZStack(alignment: .topTrailing) {
                Color.clear
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 170, height: 170)
                    .offset(x: 35, y: -55)
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 108, height: 108)
                    .offset(x: -26, y: -12)
            }
            .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color(hex: "#6B3346").opacity(0.34), radius: 16, x: 0, y: 8)
    }
}

#Preview {
    HeroCardView(
        title: "Explore\nProcedures",
        subtitle: "Find the perfect treatment for you.",
        imageName: nil
    )
    .padding()
    .background(Color(hex: "#FFF8F6"))
}
