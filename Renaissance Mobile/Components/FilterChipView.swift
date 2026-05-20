//
//  FilterChipView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

private enum FCV {
    static let text           = Color(hex: "#1E1B4B")
    static let muted          = Color(hex: "#7B6FC0")
    static let selectedBg     = Color(hex: "#EAE7FF")
    static let selectedBorder = Color(hex: "#8B7FF0")
    static let unselectedBg   = Color.white
    static let unselectedBorder = Color(hex: "#E0DBFF")
}

struct FilterChipView: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                .foregroundColor(isSelected ? FCV.text : FCV.muted)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(isSelected ? FCV.selectedBg : FCV.unselectedBg)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? FCV.selectedBorder : FCV.unselectedBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        FilterChipView(title: "Face", isSelected: true, action: {})
        FilterChipView(title: "Body", isSelected: false, action: {})
    }
    .padding()
}
