//
//  FilterChipView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct FilterChipView: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(Theme.Colors.textProceduresPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isSelected ? Theme.Colors.accentProcedures : Theme.Colors.cardBackground)
                .cornerRadius(20)
        }
    }
}

#Preview {
    HStack {
        FilterChipView(title: "Face", isSelected: true, action: {})
        FilterChipView(title: "Body", isSelected: false, action: {})
    }
    .padding()
}
