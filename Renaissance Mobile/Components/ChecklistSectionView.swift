//
//  ChecklistSectionView.swift
//  Renaissance Mobile
//

import SwiftUI

struct ChecklistSectionView: View {
    let section: ChecklistSection
    let isExpanded: Bool
    let isCompleted: (ChecklistItem) -> Bool
    let onToggle: (ChecklistItem) -> Void
    let onToggleExpand: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            Button(action: onToggleExpand) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: section.systemImage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(section.isWarningSection ? .orange : Theme.Colors.primaryHome)
                        .frame(width: 24)

                    Text(section.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(section.isWarningSection ? Color(hex: "#B45309") : Theme.Colors.textProceduresPrimary)

                    Spacer()

                    if !section.isWarningSection {
                        let completed = section.items.filter { isCompleted($0) }.count
                        Text("\(completed)/\(section.items.count)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.textProceduresSubtle)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.Colors.textProceduresSubtle)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, 14)
                .background(section.isWarningSection ? Color.orange.opacity(0.06) : Theme.Colors.cardBackground)
            }
            .buttonStyle(.plain)

            // Items
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(section.items) { item in
                        ChecklistItemRow(
                            item: item,
                            isCompleted: isCompleted(item),
                            onTap: { onToggle(item) }
                        )
                        if item.id != section.items.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(section.isWarningSection ? Color.orange.opacity(0.03) : Color(hex: "#FAFAFA"))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(
                    section.isWarningSection ? Color.orange.opacity(0.3) : Theme.Colors.borderLight,
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Checklist Item Row

private struct ChecklistItemRow: View {
    let item: ChecklistItem
    let isCompleted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                // Checkbox or warning icon
                if item.isWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                        .frame(width: 24, height: 24)
                        .padding(.top, 1)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isCompleted ? Theme.Colors.primaryHome : Theme.Colors.borderLight,
                                lineWidth: 1.5
                            )
                            .frame(width: 22, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isCompleted ? Theme.Colors.primaryHome.opacity(0.1) : Color.clear)
                            )

                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.Colors.primaryHome)
                        }
                    }
                    .frame(width: 24, height: 24)
                    .padding(.top, 1)
                }

                Text(item.text)
                    .font(.system(size: 14))
                    .foregroundColor(
                        item.isWarning
                            ? Color(hex: "#92400E")
                            : (isCompleted ? Theme.Colors.textProceduresSubtle : Theme.Colors.textProceduresPrimary)
                    )
                    .strikethrough(isCompleted && !item.isWarning, color: Theme.Colors.textProceduresSubtle)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(item.isWarning) // Red flag items are read-only
    }
}
