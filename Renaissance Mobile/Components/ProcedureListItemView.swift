//
//  ProcedureListItemView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

private enum PLCColor {
    static let surface = Color(hex: "#FBFCF8")
    static let text = Color(hex: "#1F261D")
    static let muted = Color(hex: "#687064")
    static let primary = Color(hex: "#516048")
    static let primaryInk = Color(hex: "#314030")
    static let primarySoft = Color(hex: "#D9E3CE")
    static let roseSoft = Color(hex: "#F1DDDA")
    static let lightGlass = Color.white.opacity(0.76)
    static let lightGlassStrong = Color(hex: "#FBFCF8").opacity(0.94)
    static let stroke = Color.white.opacity(0.74)
    static let shadow = Color(red: 90/255, green: 103/255, blue: 80/255).opacity(0.10)
}

private enum PLC {
    static let surfaceTop = Color.white.opacity(0.82)
    static let surfaceBottom = Color(hex: "#F5F8F0").opacity(0.94)
    static let tintTop = Color(hex: "#EDF1E8").opacity(0.92)
    static let tintBottom = Color.white.opacity(0.82)
}

private enum ProcedureListImageResolver {
    static func image(for procedure: Procedure) -> UIImage? {
        let slug = slug(for: procedure.name)
        let candidateAssetNames = [
            slug,
            "procedure-\(slug)",
            "\(slug)-hero",
            "\(slug)_hero"
        ]

        for name in candidateAssetNames {
            if let image = UIImage(named: name) {
                return image
            }
        }

        return nil
    }

    private static func slug(for name: String) -> String {
        let normalized = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " "))
        let cleanedScalars = normalized.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : " "
        }

        return String(cleanedScalars)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .joined(separator: "_")
            .lowercased()
    }
}

struct ProcedureListItemView: View {
    let procedure: Procedure
    let isSaved: Bool
    let onOpenDetails: () -> Void
    let onAskRena: () -> Void
    let onToggleSave: () -> Void

    private var summaryText: String {
        let text = procedure.editorialSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let text, !text.isEmpty {
            return text
        }
        return procedure.description
    }

    private var saveLabel: String {
        isSaved ? "Unsave" : "Save"
    }

    private var badgeLabel: String {
        isSaved ? "Saved" : "Unsaved"
    }

    private var procedureTypeLabel: String {
        procedure.isSurgical ? "Surgical" : "Non-surgical"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    procedureAvatar

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(procedure.category.uppercased())
                                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                                .tracking(2.2)
                                .foregroundColor(PLCColor.muted)

                            Spacer(minLength: 0)

                            statusBadge(label: badgeLabel, isSaved: isSaved)
                        }

                        Text(procedure.name)
                            .font(.custom("Manrope", size: 24))
                            .fontWeight(.bold)
                            .foregroundColor(PLCColor.text)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(summaryText)
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .foregroundColor(PLCColor.text.opacity(0.76))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .background(
                LinearGradient(
                    colors: [PLC.tintTop, PLC.tintBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    if !procedure.recoveryDurationLabel.isEmpty {
                        infoPill(procedure.recoveryDurationLabel, tint: PLCColor.surface, textColor: PLCColor.muted)
                    }
                    infoPill(procedureTypeLabel, tint: procedure.isSurgical ? PLCColor.roseSoft : PLCColor.primarySoft, textColor: PLCColor.primaryInk)
                    if let costRange = procedure.costRangeDisplay {
                        infoPill(costRange.replacingOccurrences(of: " – ", with: "-"), tint: PLCColor.primarySoft, textColor: PLCColor.primaryInk)
                    }
                }

                HStack(spacing: 8) {
                    actionButton("Open details", style: .primary, action: onOpenDetails)
                    actionButton("Ask Rena", style: .glass, action: onAskRena)
                    actionButton(saveLabel, style: .secondary, action: onToggleSave)
                }
            }
            .padding(18)
            .background(Color.white.opacity(0.18))
        }
        .background(
            LinearGradient(
                colors: [PLC.surfaceTop, PLC.surfaceBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
        )
        .shadow(color: PLCColor.shadow.opacity(0.85), radius: 14, x: 0, y: 6)
    }

    @ViewBuilder
    private var procedureAvatar: some View {
        ZStack {
            if let image = ProcedureListImageResolver.image(for: procedure) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                LinearGradient(
                    colors: [PLCColor.primarySoft.opacity(0.96), Color.white.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(PLCColor.primary.opacity(0.78))
                )
            }
        }
        .frame(width: 82, height: 82)
        .background(PLCColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statusBadge(label: String, isSaved: Bool) -> some View {
        Text(label)
            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
            .foregroundColor(isSaved ? PLCColor.primaryInk : PLCColor.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSaved ? PLCColor.primarySoft.opacity(0.92) : Color.white.opacity(0.72))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func infoPill(_ label: String, tint: Color, textColor: Color) -> some View {
        Text(label)
            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
            .foregroundColor(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func actionButton(_ title: String, style: ActionButtonStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                .foregroundColor(style.textColor)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 13)
                .background(style.background)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(style.borderColor, lineWidth: style.borderWidth)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ActionButtonStyle {
    let background: AnyShapeStyle
    let textColor: Color
    let borderColor: Color
    let borderWidth: CGFloat

    static let primary = ActionButtonStyle(
        background: AnyShapeStyle(PLCColor.primary),
        textColor: .white,
        borderColor: .clear,
        borderWidth: 0
    )

    static let glass = ActionButtonStyle(
        background: AnyShapeStyle(
            LinearGradient(
                colors: [PLCColor.lightGlassStrong, PLCColor.lightGlass],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        textColor: PLCColor.primaryInk,
        borderColor: PLCColor.stroke,
        borderWidth: 1
    )

    static let secondary = ActionButtonStyle(
        background: AnyShapeStyle(Color.white.opacity(0.68)),
        textColor: PLCColor.primaryInk,
        borderColor: PLCColor.stroke,
        borderWidth: 1
    )
}

#Preview {
    ZStack {
        Color(hex: "#EEF1E8").ignoresSafeArea()

        ProcedureListItemView(
            procedure: Procedure(
                id: UUID(),
                name: "Microneedling",
                description: "Collagen-induction therapy using fine needles to improve skin texture, tone, and fine lines.",
                category: "Skin",
                recoveryDurationDays: 4,
                recoveryDurationLabel: "2-4 days",
                isSurgical: false,
                sortOrder: 210,
                editorialSummary: "A lower-downtime option for improving skin texture and tone when you want gradual change without surgery.",
                defaultConsultQuestions: nil,
                heroImageURL: nil,
                thumbnailImageURL: nil,
                mediaSource: nil,
                mediaLicenseType: nil,
                mediaAltText: nil,
                usageRightsConfirmed: nil,
                whoItsFor: nil,
                recoveryOverview: nil,
                whatIsNormal: nil,
                whatToWatchFor: nil,
                costRangeMin: 400,
                costRangeMax: 900,
                relatedProcedureIds: nil
            ),
            isSaved: false,
            onOpenDetails: {},
            onAskRena: {},
            onToggleSave: {}
        )
        .padding()
    }
}
