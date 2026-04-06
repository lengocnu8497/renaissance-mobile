//
//  TypingIndicatorView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct TypingIndicatorView: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            RenaissanceAgentAvatar(size: 34)

            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color(hex: "#7E8778").opacity(index == 1 ? 0.55 : 0.32))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 26,
                    bottomLeadingRadius: 10,
                    bottomTrailingRadius: 26,
                    topTrailingRadius: 26
                )
            )

            Spacer()
        }
    }
}

#Preview {
    TypingIndicatorView()
        .padding()
        .background(Color(hex: "#F6F7F2"))
}
