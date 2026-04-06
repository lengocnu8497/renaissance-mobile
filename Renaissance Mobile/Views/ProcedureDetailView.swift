//
//  ProcedureDetailView.swift
//  Renaissance Mobile
//

import SwiftUI

private enum PDC {
    static let shell = Color(hex: "#EEF1E8")
    static let bg = Color(hex: "#F6F7F2")
    static let surface = Color(hex: "#FBFCF8")
    static let card = Color(hex: "#EDF1E8")
    static let cardStrong = Color(hex: "#E1E7DA")
    static let text = Color(hex: "#1F261D")
    static let muted = Color(hex: "#687064")
    static let primary = Color(hex: "#516048")
    static let primaryInk = Color(hex: "#314030")
    static let primarySoft = Color(hex: "#D9E3CE")
    static let roseSoft = Color(hex: "#F1DDDA")
    static let shadow = Color(red: 90/255, green: 103/255, blue: 80/255).opacity(0.10)
    static let border = Color.black.opacity(0.05)
}

struct ProcedureDetailView: View {
    let procedure: Procedure
    var allProcedures: [Procedure] = []
    var onNavigateToChat: ((String, Procedure) -> Void)?
    var onSaveProcedure: ((Procedure) -> Void)?
    var isSaved: Bool = false
    var isSavedProcedure: ((UUID) -> Bool)?

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var shareText = ""
    @State private var selectedRelated: Procedure?

    var body: some View {
        ZStack {
            PDC.shell.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroSection
                        .padding(.horizontal, 18)
                        .padding(.top, 18)

                    if procedure.whoItsFor != nil || procedure.recoveryOverview != nil {
                        overviewSection
                            .padding(.horizontal, 18)
                    }

                    if !procedure.description.isEmpty {
                        contentCard(title: "What It Is") {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(procedure.description)
                                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                                    .foregroundColor(PDC.text.opacity(0.78))
                                    .lineSpacing(4)
                            }
                        }
                        .padding(.horizontal, 18)
                    }

                    if procedure.whatIsNormal != nil || procedure.whatToWatchFor != nil {
                        expectationSection
                            .padding(.horizontal, 18)
                    }

                    relatedProcedures
                        .padding(.horizontal, 18)

                    ctaButtons
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                }
            }
        }
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top, spacing: 0) {
            detailNavBar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: 112)
        }
        .navigationDestination(item: $selectedRelated) { related in
            ProcedureDetailView(
                procedure: related,
                allProcedures: allProcedures,
                onNavigateToChat: onNavigateToChat,
                onSaveProcedure: onSaveProcedure,
                isSaved: isSavedProcedure?(related.id) ?? false,
                isSavedProcedure: isSavedProcedure
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareText])
        }
    }

    private var detailNavBar: some View {
        ZStack {
            HStack {
                Button(action: { dismiss() }) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.96))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(PDC.primaryInk)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(PDC.border, lineWidth: 1)
                        )
                        .shadow(color: PDC.shadow, radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    shareText = sharePayloadText
                    showShareSheet = true
                } label: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.96))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(PDC.primaryInk)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(PDC.border, lineWidth: 1)
                        )
                        .shadow(color: PDC.shadow, radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 2) {
                Text("Open details")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .tracking(2.1)
                    .foregroundColor(PDC.muted)
                    .textCase(.uppercase)
                Text(procedure.name)
                    .font(.custom("Manrope", size: 24))
                    .fontWeight(.heavy)
                    .foregroundColor(PDC.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 56)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(PDC.bg)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text(procedure.category.uppercased())
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .tracking(2)
                    .foregroundColor(PDC.muted)

                Text(procedure.name)
                    .font(.custom("Manrope", size: 34))
                    .fontWeight(.heavy)
                    .foregroundColor(PDC.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(editorialSubtitle)
                    .font(.custom("PlusJakartaSans-Regular", size: 15))
                    .foregroundColor(PDC.text.opacity(0.78))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if !procedure.recoveryDurationLabel.isEmpty {
                    heroPill(procedure.recoveryDurationLabel)
                }
                heroPill(procedure.isSurgical ? "Surgical" : "Non-Surgical")
                if let cost = procedure.costRangeDisplay {
                    heroPill(cost)
                }
            }

            HStack(spacing: 10) {
                heroMetric("Status", isSaved ? "Saved" : "Unsaved")
                heroMetric("Recovery", procedure.recoveryDurationLabel.isEmpty ? "Varies" : procedure.recoveryDurationLabel)
                heroMetric("Type", procedure.isSurgical ? "Surgical" : "Non-Surgical")
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(30)
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(PDC.border, lineWidth: 1))
        .shadow(color: PDC.shadow, radius: 10, x: 0, y: 3)
    }

    private func heroPill(_ text: String) -> some View {
        Text(text)
            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
            .foregroundColor(PDC.primaryInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(PDC.card)
            .clipShape(Capsule())
    }

    private func heroMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                .tracking(1.5)
                .foregroundColor(PDC.muted)
            Text(value)
                .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                .foregroundColor(PDC.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .background(PDC.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var overviewSection: some View {
        HStack(alignment: .top, spacing: 12) {
            if let whoItsFor = procedure.whoItsFor, !whoItsFor.isEmpty {
                contentMiniCard(title: "Who It's For", tint: PDC.card) {
                    Text(whoItsFor)
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundColor(PDC.text.opacity(0.78))
                        .lineSpacing(3)
                }
            }

            if let recoveryOverview = procedure.recoveryOverview, !recoveryOverview.isEmpty {
                contentMiniCard(title: "Recovery Lens", tint: PDC.cardStrong) {
                    Text(recoveryOverview)
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundColor(PDC.text.opacity(0.78))
                        .lineSpacing(3)
                }
            }
        }
    }

    private func contentMiniCard<Content: View>(
        title: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                .tracking(2.1)
                .foregroundColor(PDC.muted)
                .textCase(.uppercase)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(tint)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(PDC.border, lineWidth: 1))
        .shadow(color: PDC.shadow.opacity(0.7), radius: 8, x: 0, y: 2)
    }

    private func contentCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                .tracking(2.1)
                .foregroundColor(PDC.muted)
                .textCase(.uppercase)

            content()
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(26)
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(PDC.border, lineWidth: 1))
        .shadow(color: PDC.shadow, radius: 10, x: 0, y: 3)
    }

    private var expectationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What To Expect")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .tracking(2.1)
                    .foregroundColor(PDC.muted)
                    .textCase(.uppercase)

            }

            HStack(alignment: .top, spacing: 12) {
                if let normal = procedure.whatIsNormal {
                    expectationCard(
                        title: "Normal",
                        text: normal,
                        tint: PDC.card,
                        accent: Color(hex: "#4D7A58")
                    )
                }
                if let watch = procedure.whatToWatchFor {
                    expectationCard(
                        title: "Watch For",
                        text: watch,
                        tint: PDC.roseSoft,
                        accent: Color(hex: "#A85555")
                    )
                }
            }
        }
    }

    private func expectationCard(title: String, text: String, tint: Color, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                .tracking(1.8)
                .foregroundColor(accent)

            Text(text)
                .font(.custom("PlusJakartaSans-Regular", size: 13))
                .foregroundColor(PDC.text.opacity(0.78))
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(tint)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(PDC.border, lineWidth: 1))
    }

    @ViewBuilder
    private var relatedProcedures: some View {
        let related = relatedProcs
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Related Procedures")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                        .tracking(2.1)
                        .foregroundColor(PDC.muted)
                        .textCase(.uppercase)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(related) { rel in
                            Button { selectedRelated = rel } label: {
                                relatedChip(rel)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var relatedProcs: [Procedure] {
        guard let ids = procedure.relatedProcedureIds else { return [] }
        return allProcedures.filter { ids.contains($0.id) }
    }

    private func relatedChip(_ proc: Procedure) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(proc.category.uppercased())
                .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                .tracking(1.8)
                .foregroundColor(PDC.muted)

            Text(proc.name)
                .font(.custom("Manrope", size: 21))
                .fontWeight(.bold)
                .foregroundColor(PDC.text)
                .lineLimit(2)

            if !proc.recoveryDurationLabel.isEmpty {
                Text(proc.recoveryDurationLabel)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .foregroundColor(PDC.primaryInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PDC.card)
                    .clipShape(Capsule())
            }
        }
        .frame(width: 210)
        .frame(minHeight: 136, alignment: .leading)
        .padding(18)
        .background(Color.white)
        .cornerRadius(26)
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(PDC.border, lineWidth: 1))
        .shadow(color: PDC.shadow, radius: 10, x: 0, y: 3)
    }

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            Button {
                let context = "I want to learn more about \(procedure.name). Can you give me an overview?"
                onNavigateToChat?(context, procedure)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 16))
                    Text("Ask Rena About \(procedure.name)")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PDC.primary)
                .cornerRadius(18)
                .shadow(color: PDC.shadow, radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Button {
                onSaveProcedure?(procedure)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16))
                    Text(isSaved ? "Remove From Saved Research" : "Save To Research")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                }
                .foregroundColor(PDC.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PDC.primarySoft)
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(PDC.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                let context = consultationPrepPrompt
                onNavigateToChat?(context, procedure)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checklist")
                        .font(.system(size: 16))
                    Text("Consultation Prep Flow")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                }
                .foregroundColor(PDC.primaryInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(PDC.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var editorialSubtitle: String {
        if let editorialSummary = procedure.editorialSummary, !editorialSummary.isEmpty {
            return editorialSummary
        }
        if let overview = procedure.recoveryOverview, !overview.isEmpty {
            return overview
        }
        if let whoItsFor = procedure.whoItsFor, !whoItsFor.isEmpty {
            return whoItsFor
        }
        let trimmed = procedure.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "A refined plan for comparing results, recovery, and consultation fit." }
        if trimmed.count > 120 {
            let cutoff = trimmed.index(trimmed.startIndex, offsetBy: 120)
            return String(trimmed[..<cutoff]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }
        return trimmed
    }

    private var consultationPrepPrompt: String {
        """
        I'm researching \(procedure.name) and I have a consultation coming up. \
        Please give me a personalized Consultation Prep, formatted as three sections: \
        1) A checklist of questions to ask my surgeon, \
        2) Things I should proactively disclose to my provider, \
        3) What to look for when evaluating a provider for this procedure. \
        Please format your response as a structured guide I can bring to my appointment.
        """
    }

    private var sharePayloadText: String {
        var parts: [String] = [procedure.name]
        if let summary = procedure.editorialSummary, !summary.isEmpty {
            parts.append(summary)
        } else if !procedure.description.isEmpty {
            parts.append(procedure.description)
        }
        if let recovery = procedure.recoveryOverview, !recovery.isEmpty {
            parts.append("Recovery: \(recovery)")
        }
        if let cost = procedure.costRangeDisplay {
            parts.append("Typical cost: \(cost)")
        }
        return parts.joined(separator: "\n\n")
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

#Preview {
    ProcedureDetailView(
        procedure: Procedure(
            id: UUID(),
            name: "Rhinoplasty",
            description: "Surgical reshaping of the nose to improve appearance or correct breathing issues. Bruising and swelling peak in the first week; a splint is worn for 7-10 days. Final results settle over 12 months as residual swelling gradually subsides.",
            category: "Face",
            recoveryDurationDays: 14,
            recoveryDurationLabel: "1-2 weeks",
            isSurgical: true,
            sortOrder: 10,
            whoItsFor: "Adults in good health who are unhappy with the size, shape, or proportion of their nose.",
            recoveryOverview: "Splint worn for 7-10 days. Most bruising resolves by week 2.",
            whatIsNormal: "Significant swelling and bruising around the eyes and nose for the first 1-2 weeks.",
            whatToWatchFor: "Heavy bleeding that doesn't stop, fever over 101°F, or increasing pain after day 3.",
            costRangeMin: 7000,
            costRangeMax: 15000
        )
    )
}
