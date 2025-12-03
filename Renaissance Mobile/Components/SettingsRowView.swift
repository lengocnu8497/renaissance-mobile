//
//  SettingsRowView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI

// MARK: - Settings Row Type
enum SettingsRowType {
    case navigation
    case toggle(isOn: Binding<Bool>)
}

// MARK: - Settings Row View
struct SettingsRowView: View {
    let icon: String
    let title: String
    let type: SettingsRowType
    let action: (() -> Void)?

    init(icon: String, title: String, type: SettingsRowType = .navigation, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.type = type
        self.action = action
    }

    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack(spacing: Theme.Spacing.lg) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: Theme.IconSize.medium)

                // Title
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.Colors.textProfilePrimary)

                Spacer()

                // Trailing element
                trailingElement
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Trailing Element
    @ViewBuilder
    private var trailingElement: some View {
        switch type {
        case .navigation:
            Image(systemName: "chevron.right")
                .font(.system(size: 20))
                .foregroundColor(Color.gray.opacity(0.5))
        case .toggle(let isOn):
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.Colors.primaryProfile)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        SettingsRowView(icon: "person", title: "Personal Information")
        Divider()
        SettingsRowView(icon: "bell", title: "Notifications", type: .toggle(isOn: .constant(true)))
    }
    .background(Color.white)
}
