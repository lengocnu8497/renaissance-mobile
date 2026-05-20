//
//  ProcedureListItemView.swift
//  Renaissance Mobile
//

import SwiftUI

private enum PLCColor {
    static let bg          = Color(hex: "#EEEEFF")
    static let surface     = Color.white
    static let text        = Color(hex: "#1E1B4B")
    static let muted       = Color(hex: "#7B6FC0")
    static let primary     = Color(hex: "#6C63FF")
    static let primaryInk  = Color(hex: "#2D2575")
    static let primarySoft = Color(hex: "#EAE7FF")
    static let pillBorder  = Color(hex: "#E0DBFF")
    static let shadow      = Color(hex: "#6C63FF").opacity(0.08)
    static let cardBorder  = Color(hex: "#6C63FF").opacity(0.10)
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

private func categoryIcon(for category: String) -> String {
    switch category.lowercased() {
    case "face":         return "face.smiling"
    case "body":         return "figure.stand"
    case "skin":         return "sparkles"
    case "injectables":  return "syringe"
    case "non-surgical": return "wand.and.stars"
    case "surgical":     return "scissors"
    default:             return "plus.circle"
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
        if let text, !text.isEmpty { return text }
        return procedure.description
    }

    private var saveLabel: String { isSaved ? "Unsave" : "Save" }
    private var procedureTypeLabel: String { procedure.isSurgical ? "Surgical" : "Non-surgical" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Header row ──────────────────────────────────────────
            HStack(alignment: .top, spacing: 14) {
                procedureAvatar

                VStack(alignment: .leading, spacing: 5) {
                    Text(procedure.category.uppercased())
                        .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                        .tracking(2.2)
                        .foregroundColor(PLCColor.muted)

                    Text(procedure.name)
                        .font(.custom("Manrope", size: 20).weight(.bold))
                        .foregroundColor(PLCColor.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(summaryText)
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundColor(PLCColor.muted)
                        .lineSpacing(3)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSaved {
                    savedBadge
                }
            }

            // ── Info pills ──────────────────────────────────────────
            HStack(spacing: 6) {
                if !procedure.recoveryDurationLabel.isEmpty {
                    infoPill(procedure.recoveryDurationLabel)
                }
                infoPill(procedureTypeLabel)
                if let costRange = procedure.costRangeDisplay {
                    infoPill(costRange.replacingOccurrences(of: " – ", with: "–"))
                }
            }

            // ── Action row ──────────────────────────────────────────
            HStack(spacing: 8) {
                actionButton("Open details", isPrimary: true, action: onOpenDetails)
                actionButton("Ask Rena", isPrimary: false, action: onAskRena)
                actionButton(saveLabel, isPrimary: false, action: onToggleSave)
            }
        }
        .padding(18)
        .background(PLCColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PLCColor.cardBorder, lineWidth: 1)
        )
        .shadow(color: PLCColor.shadow, radius: 12, x: 0, y: 2)
    }

    // MARK: - Avatar

    @ViewBuilder
    private var procedureAvatar: some View {
        ZStack {
            if let image = ProcedureListImageResolver.image(for: procedure) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                PLCColor.primarySoft

                Image(systemName: categoryIcon(for: procedure.category))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(PLCColor.primary)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Saved badge

    private var savedBadge: some View {
        Text("Saved")
            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
            .foregroundColor(PLCColor.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(PLCColor.primarySoft)
            .clipShape(Capsule())
    }

    // MARK: - Info pill

    private func infoPill(_ label: String) -> some View {
        Text(label)
            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
            .foregroundColor(PLCColor.primaryInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(PLCColor.pillBorder, lineWidth: 1))
    }

    // MARK: - Action button

    private func actionButton(_ title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                .foregroundColor(isPrimary ? .white : PLCColor.primaryInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(isPrimary ? PLCColor.primary : Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isPrimary ? Color.clear : PLCColor.pillBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color(hex: "#EEEEFF").ignoresSafeArea()

        ProcedureListItemView(
            procedure: Procedure(
                id: UUID(),
                name: "Microneedling",
                description: "Collagen-induction therapy using fine needles to improve skin texture, tone, and fine lines.",
                category: "Skin",
                recoveryDurationDays: 4,
                recoveryDurationLabel: "2–4 days",
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
