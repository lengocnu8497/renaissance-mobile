//
//  ProcedureDetailView.swift
//  Renaissance Mobile
//

import SwiftUI

struct ProcedureDetailView: View {
    let procedure: Procedure
    var allProcedures: [Procedure] = []
    var onNavigateToChat: ((String, Procedure) -> Void)?
    var onSaveProcedure: ((Procedure) -> Void)?
    var isSaved: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var shareText = ""
    @State private var selectedRelated: Procedure?

    var body: some View {
        ZStack(alignment: .top) {
            Theme.Colors.pageBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroHeader
                    contentSections
                    relatedProcedures
                    actionButtons
                        .padding(.bottom, 40)
                }
            }

            // Floating nav bar
            navBar
        }
        .navigationBarHidden(true)
        .navigationDestination(item: $selectedRelated) { related in
            ProcedureDetailView(
                procedure: related,
                allProcedures: allProcedures,
                onNavigateToChat: onNavigateToChat,
                onSaveProcedure: onSaveProcedure,
                isSaved: false
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareText])
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            }

            Spacer()

            Button {
                onSaveProcedure?(procedure)
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isSaved ? Theme.Colors.primary : Theme.Colors.textPrimary)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 56)
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background
            Theme.Gradients.hero
                .frame(height: 240)

            // Decorative ring
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 200, height: 200)
                .offset(x: 260, y: -40)

            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .frame(width: 140, height: 140)
                .offset(x: 290, y: 20)

            VStack(alignment: .leading, spacing: 8) {
                // Surgical / non-surgical badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(procedure.isSurgical ? Color(hex: "#EF4444").opacity(0.8) : Color(hex: "#10B981").opacity(0.8))
                        .frame(width: 6, height: 6)
                    Text(procedure.isSurgical ? "Surgical" : "Non-Surgical")
                        .font(.custom("Outfit-SemiBold", size: 10))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())

                Text(procedure.name)
                    .font(.system(size: 30, weight: .light, design: .serif))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                // Category chip
                Text(procedure.category)
                    .font(.custom("Outfit-Regular", size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Content Sections

    private var contentSections: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Description
            detailSection(icon: "text.alignleft", title: "What It Is") {
                Text(procedure.description)
                    .font(.custom("Outfit-Light", size: 14))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            divider

            // Who it's for
            if let who = procedure.whoItsFor {
                detailSection(icon: "person.fill", title: "Who It's For") {
                    Text(who)
                        .font(.custom("Outfit-Light", size: 14))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                divider
            }

            // Recovery overview
            if let recovery = procedure.recoveryOverview {
                detailSection(icon: "calendar", title: "Recovery Timeline") {
                    Text(recovery)
                        .font(.custom("Outfit-Light", size: 14))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    // Duration badge
                    if !procedure.recoveryDurationLabel.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text(procedure.recoveryDurationLabel)
                                .font(.custom("Outfit-SemiBold", size: 12))
                        }
                        .foregroundColor(Theme.Colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.primary.opacity(0.08))
                        .clipShape(Capsule())
                        .padding(.top, 6)
                    }
                }
                divider
            }

            // What's normal vs watch for — two-column style card
            if procedure.whatIsNormal != nil || procedure.whatToWatchFor != nil {
                normalVsWatchCard
                divider
            }

            // Cost range
            if let cost = procedure.costRangeDisplay {
                detailSection(icon: "dollarsign.circle", title: "Typical Cost Range") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cost)
                            .font(.system(size: 22, weight: .light, design: .serif))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("Estimates vary by provider, location, and procedure scope. Always get multiple consultations.")
                            .font(.custom("Outfit-Light", size: 12))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                divider
            }
        }
        .background(Color.white)
    }

    // MARK: - Normal vs Watch For Card

    private var normalVsWatchCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.primary)
                Text("What to Expect")
                    .font(.custom("Outfit-SemiBold", size: 14))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            VStack(spacing: 12) {
                // What's normal
                if let normal = procedure.whatIsNormal {
                    expectationBlock(
                        icon: "checkmark.circle.fill",
                        iconColor: Color(hex: "#10B981"),
                        label: "WHAT'S NORMAL",
                        tint: Color(hex: "#10B981").opacity(0.06),
                        borderColor: Color(hex: "#10B981").opacity(0.18),
                        text: normal
                    )
                }

                // What to watch for
                if let watch = procedure.whatToWatchFor {
                    expectationBlock(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: Color(hex: "#F59E0B"),
                        label: "WHAT TO WATCH FOR",
                        tint: Color(hex: "#F59E0B").opacity(0.06),
                        borderColor: Color(hex: "#F59E0B").opacity(0.18),
                        text: watch
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func expectationBlock(icon: String, iconColor: Color, label: String, tint: Color, borderColor: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.custom("Outfit-SemiBold", size: 9))
                    .tracking(2)
                    .foregroundColor(iconColor)
            }
            Text(text)
                .font(.custom("Outfit-Light", size: 13))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 1))
        .cornerRadius(12)
    }

    // MARK: - Related Procedures

    @ViewBuilder
    private var relatedProcedures: some View {
        let related = relatedProcs
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Related Procedures")
                    .font(.custom("Outfit-SemiBold", size: 14))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(related) { rel in
                            Button { selectedRelated = rel } label: {
                                relatedChip(rel)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 8)
            }
            .background(Theme.Colors.pageBg)
        }
    }

    private var relatedProcs: [Procedure] {
        guard let ids = procedure.relatedProcedureIds else { return [] }
        return allProcedures.filter { ids.contains($0.id) }
    }

    private func relatedChip(_ proc: Procedure) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(proc.category)
                .font(.custom("Outfit-Regular", size: 9))
                .tracking(1)
                .foregroundColor(Theme.Colors.textSecondary)

            Text(proc.name)
                .font(.custom("Outfit-SemiBold", size: 13))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)

            if !proc.recoveryDurationLabel.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(proc.recoveryDurationLabel)
                        .font(.custom("Outfit-Light", size: 11))
                }
                .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .frame(width: 140, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.border, lineWidth: 1))
        .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius, x: 0, y: 2)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Ask About This Procedure
            Button {
                let context = "I want to learn more about \(procedure.name). Can you give me an overview?"
                onNavigateToChat?(context, procedure)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 16))
                    Text("Ask About This Procedure")
                        .font(.custom("Outfit-SemiBold", size: 15))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.Gradients.hero)
                .cornerRadius(16)
                .shadow(color: Theme.Shadow.button.color, radius: Theme.Shadow.button.radius, x: 0, y: 4)
            }

            // Consultation Prep Flow
            Button {
                let context = consultationPrepPrompt
                onNavigateToChat?(context, procedure)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checklist")
                        .font(.system(size: 16))
                    Text("Consultation Prep Flow")
                        .font(.custom("Outfit-SemiBold", size: 15))
                }
                .foregroundColor(Theme.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.Colors.primary.opacity(0.08))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
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

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(Theme.Colors.border)
            .frame(height: 1)
            .padding(.horizontal, 20)
    }

    private func detailSection<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.primary)
                Text(title)
                    .font(.custom("Outfit-SemiBold", size: 14))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
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
            description: "Surgical reshaping of the nose to improve appearance or correct breathing issues.",
            category: "Face",
            recoveryDurationDays: 14,
            recoveryDurationLabel: "1–2 weeks",
            isSurgical: true,
            sortOrder: 10,
            whoItsFor: "Adults in good health who are unhappy with the size, shape, or proportion of their nose.",
            recoveryOverview: "Splint worn for 7–10 days. Most bruising resolves by week 2.",
            whatIsNormal: "Significant swelling and bruising around the eyes and nose for the first 1–2 weeks.",
            whatToWatchFor: "Heavy bleeding that doesn't stop, fever over 101°F, or increasing pain after day 3.",
            costRangeMin: 7000,
            costRangeMax: 15000
        )
    )
}
