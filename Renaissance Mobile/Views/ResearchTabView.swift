//
//  ResearchTabView.swift
//  Renaissance Mobile
//
//  Pre-Procedure Mode — save procedures you're researching,
//  track questions, and store consultation notes.
//

import SwiftUI

private enum RC {
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

private enum ResearchProcedureImageResolver {
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

private struct ResearchDetailNavBar: View {
    let title: String
    let canExport: Bool
    let onBack: () -> Void
    let onExport: () -> Void

    var body: some View {
        ZStack {
            HStack {
                Button(action: onBack) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.96))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(RC.primaryInk)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(RC.border, lineWidth: 1)
                        )
                        .shadow(color: RC.shadow, radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onExport) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.96))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(RC.primaryInk)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(RC.border, lineWidth: 1)
                        )
                        .shadow(color: RC.shadow, radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(!canExport)
                .opacity(canExport ? 1 : 0.45)
            }

            VStack(spacing: 2) {
                Text("Open details")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .tracking(2.1)
                    .foregroundColor(RC.muted)
                    .textCase(.uppercase)
                Text(title)
                    .font(.custom("Manrope", size: 24))
                    .fontWeight(.heavy)
                    .foregroundColor(RC.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 56)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(RC.bg)
    }
}

private struct ResearchDetailHeroCard: View {
    let procedure: Procedure
    let subtitle: String
    let metrics: [(label: String, value: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text(procedure.category.uppercased())
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .tracking(2)
                    .foregroundColor(RC.muted)

                Text(procedure.name)
                    .font(.custom("Manrope", size: 34))
                    .fontWeight(.heavy)
                    .foregroundColor(RC.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.custom("PlusJakartaSans-Regular", size: 15))
                    .foregroundColor(RC.text.opacity(0.78))
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
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    heroMetric(metric.label, metric.value)
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(30)
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(RC.border, lineWidth: 1))
        .shadow(color: RC.shadow, radius: 10, x: 0, y: 3)
    }

    private func heroPill(_ text: String) -> some View {
        Text(text)
            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
            .foregroundColor(RC.primaryInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RC.card)
            .clipShape(Capsule())
    }

    private func heroMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                .tracking(1.5)
                .foregroundColor(RC.muted)
            Text(value)
                .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                .foregroundColor(RC.text)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .background(RC.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct ResearchTabView: View {
    @State private var viewModel = ResearchViewModel()
    @State private var proceduresViewModel = ProceduresViewModel()
    @State private var selectedProcedure: Procedure?
    @State private var showExploreSheet = false
    @State private var selectedSavedForDetail: SavedProcedure?
    @State private var recentSessions: [ChatConversation] = []
    @State private var loadingRecentSessions = false
    var onNavigateToChat: ((String, Procedure?, UUID?) -> Void)?
    var onReopenConversation: ((UUID) -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                RC.shell.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    content
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedProcedure) { procedure in
                ProcedureDetailView(
                    procedure: procedure,
                    allProcedures: proceduresViewModel.procedures,
                    onNavigateToChat: { msg, proc in
                        onNavigateToChat?(msg, proc, nil)
                    },
                    onSaveProcedure: { [viewModel] proc in
                        Task { await viewModel.toggleSave(proc) }
                    },
                    isSaved: viewModel.isSaved(procedure.id)
                )
            }
            .navigationDestination(item: $selectedSavedForDetail) { saved in
                if let proc = viewModel.procedure(for: saved) {
                    SavedProcedureDetailView(
                        saved: saved,
                        procedure: proc,
                        viewModel: viewModel,
                        onNavigateToChat: { msg, savedId in
                            onNavigateToChat?(msg, proc, savedId)
                        },
                        onReopenConversation: onReopenConversation
                    )
                }
            }
            .sheet(isPresented: $showExploreSheet) {
                NavigationStack {
                    ProceduresListView(
                        initialSavedIds: Set(viewModel.savedProcedures.map { $0.procedureId }),
                        researchViewModel: viewModel,
                        onBackButtonTapped: { showExploreSheet = false },
                        onNavigateToChat: { msg, proc in
                            showExploreSheet = false
                            onNavigateToChat?(msg, proc, nil)
                        }
                    )
                }
            }
            .onChange(of: showExploreSheet) { _, isPresented in
                guard !isPresented else { return }
                Task {
                    await viewModel.load()
                    await loadRecentSessions()
                }
            }
            .task {
                await viewModel.load()
                await proceduresViewModel.fetchProcedures()
                await loadRecentSessions()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Research")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                        .tracking(2.2)
                        .foregroundColor(RC.muted)
                        .textCase(.uppercase)
                    Text("Procedures to explore")
                        .font(.custom("Manrope", size: 28))
                        .fontWeight(.heavy)
                        .foregroundColor(RC.text)
                }
                Spacer()
                Button {
                    showExploreSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(RC.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: RC.shadow, radius: 12, x: 0, y: 4)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 54)
        .padding(.bottom, 10)
        .background(RC.bg)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView()
                .tint(RC.primary)
            Spacer()
        } else {
            savedList
        }
    }

    // MARK: - Saved List

    private var savedList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                shortlistShelf
                exploreNextSection

                savedResearchSection

                consultationPrepSection

                researchSessionsSection
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 100)
            .padding(.top, 4)
        }
    }

    private var shortlistShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your Shortlist")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                        .tracking(2.1)
                        .foregroundColor(RC.muted)
                        .textCase(.uppercase)
                    Text("Saved procedures")
                        .font(.custom("Manrope", size: 24))
                        .fontWeight(.bold)
                        .foregroundColor(RC.primaryInk)
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if viewModel.shortlistCards.isEmpty {
                        emptyShortlistCard(
                            title: "Save your first procedure",
                            subtitle: "Your shortlist lives here. Save 1-2 procedures you're considering so you can compare recovery, questions, and sessions in one place.",
                            accent: .white
                        )
                        emptyShortlistCard(
                            title: "Build your consultation prep",
                            subtitle: "Once saved, each procedure gets its own notes, questions, and a direct path to Ask Rena.",
                            accent: RC.card
                        )
                    } else {
                        ForEach(viewModel.shortlistCards) { card in
                            Button {
                                selectedSavedForDetail = viewModel.savedEntry(for: card.procedure.id)
                            } label: {
                                ZStack(alignment: .bottomLeading) {
                                    Group {
                                        if let image = ResearchProcedureImageResolver.image(for: card.procedure) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            LinearGradient(
                                                colors: [RC.primarySoft.opacity(0.92), RC.cardStrong.opacity(0.96)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        }
                                    }
                                    .frame(width: 210, height: 164)
                                    .clipped()

                                    LinearGradient(
                                        colors: [
                                            Color.black.opacity(0.02),
                                            Color.black.opacity(0.12),
                                            Color.black.opacity(0.64),
                                            Color.black.opacity(0.82)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )

                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(card.procedure.category.uppercased())
                                            .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                                            .tracking(1.8)
                                            .foregroundColor(.white.opacity(0.82))

                                        Text(card.procedure.name)
                                            .font(.custom("Manrope", size: 21))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .lineLimit(2)

                                        HStack(spacing: 6) {
                                            if !card.procedure.recoveryDurationLabel.isEmpty {
                                                pillLabel(card.procedure.recoveryDurationLabel, tint: Color.black.opacity(0.28), textColor: .white)
                                            }
                                            if card.questionCount > 0 {
                                                pillLabel("\(card.questionCount) questions", tint: RC.roseSoft.opacity(0.92), textColor: RC.primaryInk)
                                            }
                                        }
                                    }
                                    .padding(18)
                                }
                                .frame(width: 210)
                                .frame(minHeight: 164, alignment: .leading)
                                .cornerRadius(26)
                                .overlay(RoundedRectangle(cornerRadius: 26).stroke(RC.border, lineWidth: 1))
                                .shadow(color: RC.shadow, radius: 10, x: 0, y: 3)
                                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var exploreNextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Explore Next")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                        .tracking(2.1)
                        .foregroundColor(RC.muted)
                        .textCase(.uppercase)
                }
                Spacer()
                Image(systemName: "safari")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(RC.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(exploreSuggestions, id: \.self) { suggestion in
                        Button {
                            showExploreSheet = true
                        } label: {
                            Text(suggestion)
                                .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                                .foregroundColor(RC.primaryInk)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(RC.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(16)
        .background(RC.card)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(RC.border, lineWidth: 1))
    }

    private var savedResearchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Saved Research")
                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                .tracking(2.1)
                .foregroundColor(RC.muted)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            if viewModel.shortlistCards.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Save a procedure to unlock details")
                                .font(.custom("Manrope", size: 24))
                                .fontWeight(.bold)
                                .foregroundColor(RC.text)
                        }
                    }

                    HStack(spacing: 8) {
                        pillLabel("Recovery timeline", tint: Color.white, textColor: RC.muted)
                        pillLabel("Questions", tint: RC.roseSoft, textColor: RC.primaryInk)
                        pillLabel("Ask Rena", tint: RC.primarySoft, textColor: RC.primaryInk)
                    }

                    Text("Saved procedures become your research workspace. You’ll see recovery tags, cost context, your own questions, and quick actions to open details or continue with Rena.")
                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                        .foregroundColor(RC.text.opacity(0.74))
                        .lineSpacing(3)

                    HStack(spacing: 12) {
                        Button {
                            showExploreSheet = true
                        } label: {
                            Text("Explore procedures")
                                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(RC.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            let prompt = "Help me compare procedures and figure out what to research first."
                            onNavigateToChat?(prompt, nil, nil)
                        } label: {
                            Text("Ask Rena")
                                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                .foregroundColor(RC.primaryInk)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(RC.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
                .background(RC.surface)
                .cornerRadius(28)
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(RC.border, lineWidth: 1))
                .shadow(color: RC.shadow, radius: 10, x: 0, y: 3)
            } else {
                ForEach(viewModel.shortlistCards) { card in
                    savedCard(card: card)
                }
            }
        }
    }

    private var consultationPrepSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Consultation Prep")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                        .tracking(2.1)
                        .foregroundColor(RC.muted)
                        .textCase(.uppercase)
                    Text("Questions to bring")
                        .font(.custom("Manrope", size: 24))
                        .fontWeight(.bold)
                        .foregroundColor(RC.text)
                }
                Spacer()
                Image(systemName: "text.bubble")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(RC.primary)
            }

            if let featuredCard = featuredQuestionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(featuredCard.procedure.name)
                        .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                        .foregroundColor(RC.primaryInk)

                    ForEach(featuredCard.questions, id: \.self) { question in
                        Text(question)
                            .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                            .foregroundColor(RC.primaryInk)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(RC.card)
                            .cornerRadius(22)
                    }
                }
                .padding(18)
                .background(Color.white)
                .cornerRadius(28)
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(RC.border, lineWidth: 1))
                .shadow(color: RC.shadow, radius: 10, x: 0, y: 3)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Start collecting questions before your consult.")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                        .foregroundColor(RC.primaryInk)
                    Text("Once you save a procedure, this section becomes your consult-prep stack. Start with questions like:")
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundColor(RC.muted)
                        .lineSpacing(3)

                    ForEach(exampleConsultationQuestions, id: \.self) { question in
                        Text(question)
                            .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                            .foregroundColor(RC.primaryInk)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(RC.card)
                            .cornerRadius(22)
                    }
                }
                .padding(18)
                .background(Color.white)
                .cornerRadius(28)
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(RC.border, lineWidth: 1))
            }
        }
    }

    private var researchSessionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Research Sessions")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                        .tracking(2.1)
                        .foregroundColor(RC.muted)
                        .textCase(.uppercase)
                    Text("Continue where you left off")
                        .font(.custom("Manrope", size: 24))
                        .fontWeight(.bold)
                        .foregroundColor(RC.text)
                }
                Spacer()
                if loadingRecentSessions {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(RC.primary)
                } else {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(RC.primary)
                }
            }

            if recentSessions.isEmpty && !loadingRecentSessions {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your future research chats will live here.")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                        .foregroundColor(RC.primaryInk)
                    Text("Ask Rena about a procedure, then come back here to quickly resume your research without starting over.")
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundColor(RC.muted)
                        .lineSpacing(3)

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Example session")
                                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                .foregroundColor(RC.text)
                            Text("Rhinoplasty consultation prep • resume later")
                                .font(.custom("PlusJakartaSans-Regular", size: 11))
                                .foregroundColor(RC.muted)
                        }
                        Spacer()
                        Text("Resume")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                            .foregroundColor(RC.primaryInk)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(22)
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(RC.border, lineWidth: 1))
                }
                .padding(18)
                .background(RC.cardStrong)
                .cornerRadius(28)
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(RC.border, lineWidth: 1))
            } else {
                VStack(spacing: 10) {
                    ForEach(recentSessions.prefix(3)) { conversation in
                        Button {
                            onReopenConversation?(conversation.id)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(conversation.title ?? "Research session")
                                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                        .foregroundColor(RC.text)
                                        .lineLimit(2)
                                    Text(sessionSubtitle(for: conversation))
                                        .font(.custom("PlusJakartaSans-Regular", size: 11))
                                        .foregroundColor(RC.muted)
                                }
                                Spacer()
                                Text("Resume")
                                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                                    .foregroundColor(RC.primaryInk)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(RC.card)
                                    .clipShape(Capsule())
                            }
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(22)
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(RC.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(onReopenConversation == nil)
                        .opacity(onReopenConversation == nil ? 0.55 : 1)
                    }
                }
                .padding(18)
                .background(RC.cardStrong)
                .cornerRadius(28)
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(RC.border, lineWidth: 1))
            }
        }
    }

    private func savedCard(card: SavedProcedureCardModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(card.procedure.category.uppercased())
                        .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                        .tracking(1.8)
                        .foregroundColor(RC.muted)
                    Text(card.procedure.name)
                        .font(.custom("Manrope", size: 25))
                        .fontWeight(.bold)
                        .foregroundColor(RC.text)
                }
                Spacer()
                Text("saved")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .foregroundColor(RC.primaryInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                if !card.procedure.recoveryDurationLabel.isEmpty {
                    pillLabel(card.procedure.recoveryDurationLabel, tint: Color.white, textColor: RC.muted)
                }

                pillLabel(
                    card.procedure.isSurgical ? "Surgical" : "Non-Surgical",
                    tint: card.procedure.isSurgical ? RC.roseSoft : RC.primarySoft,
                    textColor: RC.primaryInk
                )

                if let cost = card.procedure.costRangeDisplay {
                    pillLabel(cost, tint: RC.primarySoft, textColor: RC.primaryInk)
                }
            }

            Text(card.procedure.description)
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundColor(RC.text.opacity(0.74))
                .lineLimit(3)
                .lineSpacing(4)

            HStack(spacing: 10) {
                metricTile("Questions", "\(card.questionCount)", card.questionCount == 1 ? "saved" : "saved")
                metricTile("Sessions", "\(card.linkedSessionCount)", card.linkedSessionCount > 0 ? "active" : "none yet")
            }

            HStack(spacing: 12) {
                Button {
                    selectedSavedForDetail = viewModel.savedEntry(for: card.procedure.id)
                } label: {
                    Text("Open details")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RC.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    let msg = "I'm researching \(card.procedure.name) and I have some questions about it."
                    onNavigateToChat?(msg, card.procedure, card.savedId)
                } label: {
                    Text("Ask Rena")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                        .foregroundColor(RC.primaryInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(RC.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(onNavigateToChat == nil)
                .opacity(onNavigateToChat == nil ? 0.55 : 1)
            }
        }
        .padding(18)
        .background(RC.surface)
        .cornerRadius(28)
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(RC.border, lineWidth: 1))
        .shadow(color: RC.shadow, radius: 10, x: 0, y: 3)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { [viewModel] in await viewModel.toggleSave(card.procedure) }
            } label: {
                Label("Remove", systemImage: "bookmark.slash")
            }
        }
    }

    private func pillLabel(_ text: String, tint: Color, textColor: Color) -> some View {
        Text(text)
            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
            .foregroundColor(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint)
            .clipShape(Capsule())
    }

    private func metricTile(_ label: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                .tracking(1.4)
                .foregroundColor(RC.muted)
                .textCase(.uppercase)
            Text(value)
                .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                .foregroundColor(RC.primaryInk)
            Text(detail)
                .font(.custom("PlusJakartaSans-Regular", size: 11))
                .foregroundColor(RC.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Color.white)
        .cornerRadius(22)
    }

    private func emptyShortlistCard(title: String, subtitle: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EXAMPLE")
                .font(.custom("PlusJakartaSans-SemiBold", size: 9))
                .tracking(1.8)
                .foregroundColor(RC.muted)

            Text(title)
                .font(.custom("Manrope", size: 21))
                .fontWeight(.bold)
                .foregroundColor(RC.text)
                .lineLimit(2)

            Text(subtitle)
                .font(.custom("PlusJakartaSans-Regular", size: 13))
                .foregroundColor(RC.text.opacity(0.72))
                .lineSpacing(3)

            HStack(spacing: 6) {
                pillLabel("Save", tint: .white, textColor: RC.muted)
                pillLabel("Questions", tint: RC.roseSoft, textColor: RC.primaryInk)
            }
        }
        .frame(width: 210)
        .frame(minHeight: 144, alignment: .leading)
        .padding(18)
        .background(accent)
        .cornerRadius(26)
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(RC.border, lineWidth: 1))
        .shadow(color: RC.shadow, radius: 10, x: 0, y: 3)
    }

    private var featuredQuestionCard: (procedure: Procedure, questions: [String])? {
        for saved in viewModel.savedProcedures {
            guard !saved.questions.isEmpty, let procedure = viewModel.procedure(for: saved) else { continue }
            return (procedure, Array(saved.questions.prefix(3)))
        }
        return nil
    }

    private func shortlistSurface(for id: UUID) -> Color {
        guard let idx = viewModel.shortlistCards.firstIndex(where: { $0.id == id }) else { return .white }
        switch idx % 3 {
        case 1: return RC.card
        case 2: return RC.cardStrong
        default: return .white
        }
    }

    private func sessionSubtitle(for conversation: ChatConversation) -> String {
        "\(RelativeDateTimeFormatter().localizedString(for: conversation.updatedAt, relativeTo: Date()).capitalized) • saved research"
    }

    private var exploreSuggestions: [String] {
        if viewModel.shortlistCards.isEmpty {
            return [
                "Natural-result rhinoplasty",
                "Mini facelift recovery",
                "Lower bleph cost"
            ]
        }
        return viewModel.exploreSuggestions
    }

    private var exampleConsultationQuestions: [String] {
        [
            "What changes are realistic for my features and anatomy?",
            "How long will swelling or downtime affect what I see?",
            "Can you walk me through before-and-afters similar to my case?"
        ]
    }

    private func loadRecentSessions() async {
        loadingRecentSessions = true
        defer { loadingRecentSessions = false }

        let conversationIds = Array(Set(viewModel.savedProcedures.flatMap(\.conversationIds)))
        let conversations = await viewModel.fetchConversations(for: conversationIds)
        recentSessions = conversations.sorted { $0.updatedAt > $1.updatedAt }
    }
}

// MARK: - Saved Procedure Detail (questions + notes + export)

struct SavedProcedureDetailView: View {
    private enum NotesSaveState {
        case idle
        case saving
        case saved
        case failed
    }

    let saved: SavedProcedure
    let procedure: Procedure
    @Bindable var viewModel: ResearchViewModel
    var onNavigateToChat: ((String, UUID?) -> Void)?
    var onReopenConversation: ((UUID) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var newQuestion = ""
    @State private var notes: String
    @State private var showShareSheet = false
    @State private var exportText = ""
    @State private var notesSaveTask: Task<Void, Never>?
    @State private var linkedConversations: [ChatConversation] = []
    @State private var loadingConversations = false
    @State private var notesSaveState: NotesSaveState = .idle
    @FocusState private var questionFieldFocused: Bool

    private static let sessionDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()

    init(
        saved: SavedProcedure,
        procedure: Procedure,
        viewModel: ResearchViewModel,
        onNavigateToChat: ((String, UUID?) -> Void)? = nil,
        onReopenConversation: ((UUID) -> Void)? = nil
    ) {
        self.saved = saved
        self.procedure = procedure
        self.viewModel = viewModel
        self.onNavigateToChat = onNavigateToChat
        self.onReopenConversation = onReopenConversation
        self._notes = State(initialValue: saved.notes ?? "")
    }

    private var currentSaved: SavedProcedure {
        viewModel.savedEntry(for: procedure.id) ?? saved
    }

    private var heroMetrics: [(label: String, value: String)] {
        [
            ("Saved Qs", "\(currentSaved.questions.count)"),
            ("Sessions", "\(linkedConversations.count)"),
            ("Notes", currentSaved.notes?.isEmpty == false ? "Yes" : "No")
        ]
    }

    var body: some View {
        ZStack {
            RC.shell.ignoresSafeArea()

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
                                    .foregroundColor(RC.text.opacity(0.78))
                                    .lineSpacing(4)
                            }
                        }
                        .padding(.horizontal, 18)
                    }

                    if procedure.whatIsNormal != nil || procedure.whatToWatchFor != nil {
                        expectationSection
                            .padding(.horizontal, 18)
                    }

                    questionsSection

                    notesSection

                    researchSessionsSection

                    ctaButtons
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
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [exportText])
        }
        .task {
            await viewModel.refresh(savedId: saved.id)
            loadingConversations = true
            linkedConversations = await viewModel.fetchConversations(for: currentSaved.conversationIds)
            loadingConversations = false
        }
        .onDisappear {
            notesSaveTask?.cancel()
        }
    }

    private var detailNavBar: some View {
        ResearchDetailNavBar(
            title: procedure.name,
            canExport: !exportPayloadText.isEmpty,
            onBack: { dismiss() },
            onExport: {
                exportText = exportPayloadText
                showShareSheet = true
            }
        )
    }

    private var heroSection: some View {
        ResearchDetailHeroCard(
            procedure: procedure,
            subtitle: editorialSubtitle,
            metrics: heroMetrics
        )
    }

    private var overviewSection: some View {
        HStack(alignment: .top, spacing: 12) {
            if let whoItsFor = procedure.whoItsFor, !whoItsFor.isEmpty {
                contentMiniCard(title: "Who It's For", tint: RC.card) {
                    Text(whoItsFor)
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundColor(RC.text.opacity(0.78))
                        .lineSpacing(3)
                }
            }

            if let recoveryOverview = procedure.recoveryOverview, !recoveryOverview.isEmpty {
                contentMiniCard(title: "Recovery Lens", tint: RC.cardStrong) {
                    Text(recoveryOverview)
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundColor(RC.text.opacity(0.78))
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
                .foregroundColor(RC.muted)
                .textCase(.uppercase)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(tint)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(RC.border, lineWidth: 1))
        .shadow(color: RC.shadow.opacity(0.7), radius: 8, x: 0, y: 2)
    }

    private func contentCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                .tracking(2.1)
                .foregroundColor(RC.muted)
                .textCase(.uppercase)

            content()
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(26)
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(RC.border, lineWidth: 1))
        .shadow(color: RC.shadow, radius: 10, x: 0, y: 3)
    }

    private var expectationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What To Expect")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .tracking(2.1)
                    .foregroundColor(RC.muted)
                    .textCase(.uppercase)

            }

            HStack(alignment: .top, spacing: 12) {
                if let normal = procedure.whatIsNormal {
                    expectationCard(
                        title: "Normal",
                        text: normal,
                        tint: RC.card,
                        accent: Color(hex: "#4D7A58")
                    )
                }
                if let watch = procedure.whatToWatchFor {
                    expectationCard(
                        title: "Watch For",
                        text: watch,
                        tint: RC.roseSoft,
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
                .foregroundColor(RC.text.opacity(0.78))
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(tint)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(RC.border, lineWidth: 1))
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

    // MARK: - Questions

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Consultation Questions")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                        .tracking(2.1)
                        .foregroundColor(RC.muted)
                        .textCase(.uppercase)
                    Text("Save the questions you want to bring into a real consultation.")
                        .font(.custom("PlusJakartaSans-Regular", size: 12))
                        .foregroundColor(RC.muted)
                }
                Spacer()
                if isUsingSuggestedQuestions {
                    Text("Suggested")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                        .foregroundColor(RC.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RC.primarySoft)
                        .clipShape(Capsule())
                } else {
                    Text("\(currentSaved.questions.count) saved")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                        .foregroundColor(RC.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RC.primarySoft)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 18)

            if !displayQuestions.isEmpty {
                curatedQuestionsPreview
                    .padding(.horizontal, 18)
            }

            // Add question input
            HStack(spacing: 10) {
                TextField("Add a question...", text: $newQuestion)
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .foregroundColor(RC.text)
                    .focused($questionFieldFocused)
                    .onSubmit { submitQuestion() }

                Button { submitQuestion() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(newQuestion.isEmpty ? RC.muted : RC.primary)
                }
                .disabled(newQuestion.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(RC.border, lineWidth: 1))
            .padding(.horizontal, 18)

            if currentSaved.questions.isEmpty {
                Text(isUsingSuggestedQuestions ? "Suggested questions are ready above. Save the ones you want to bring, or add your own." : "No questions yet. Add the questions you want to ask your surgeon.")
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundColor(RC.muted)
                    .lineSpacing(3)
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(currentSaved.questions.enumerated()), id: \.offset) { idx, question in
                        HStack(alignment: .top, spacing: 10) {
                            Text("·")
                                .font(.custom("PlusJakartaSans-SemiBold", size: 18))
                                .foregroundColor(RC.primary)
                                .offset(y: -2)
                            Text(question)
                                .font(.custom("PlusJakartaSans-Regular", size: 14))
                                .foregroundColor(RC.text)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button {
                                Task { await viewModel.removeQuestion(at: idx, from: saved.id) }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11))
                                    .foregroundColor(RC.muted)
                                    .padding(6)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)

                        if idx < currentSaved.questions.count - 1 {
                            Divider()
                                .padding(.horizontal, 18)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(22)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(RC.border, lineWidth: 1))
                .padding(.horizontal, 18)
            }
        }
        .padding(.bottom, 8)
    }

    private var curatedQuestionsPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Questions to bring")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                    .foregroundColor(RC.primaryInk)

                if isUsingSuggestedQuestions {
                    Text("Suggested for consultation")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                        .foregroundColor(RC.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RC.primarySoft)
                        .clipShape(Capsule())
                }
            }

            ForEach(Array(displayQuestions.prefix(3)), id: \.self) { question in
                HStack(alignment: .top, spacing: 10) {
                    Text("•")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                        .foregroundColor(RC.primary)
                    Text(question)
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                        .foregroundColor(RC.primaryInk)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(RC.card)
                .cornerRadius(20)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(RC.border, lineWidth: 1))
    }

    private var displayQuestions: [String] {
        if !currentSaved.questions.isEmpty {
            return currentSaved.questions
        }
        return procedure.defaultConsultQuestions ?? []
    }

    private var isUsingSuggestedQuestions: Bool {
        currentSaved.questions.isEmpty && !(procedure.defaultConsultQuestions?.isEmpty ?? true)
    }

    private func submitQuestion() {
        let q = newQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        newQuestion = ""
        questionFieldFocused = false
        Task { await viewModel.addQuestion(q, to: saved.id) }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Consultation Notes")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .tracking(2.1)
                    .foregroundColor(RC.muted)
                    .textCase(.uppercase)

                Spacer()

                Text(notesSaveStatusText)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .foregroundColor(notesSaveStatusColor)
            }
            .padding(.horizontal, 18)

            TextEditor(text: $notes)
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundColor(RC.text)
                .frame(minHeight: 112)
                .padding(14)
                .background(Color.white)
                .cornerRadius(22)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(RC.border, lineWidth: 1))
                .padding(.horizontal, 18)
                .onChange(of: notes) { _, newValue in
                    notesSaveTask?.cancel()
                    notesSaveState = .saving
                    notesSaveTask = Task {
                        try? await Task.sleep(for: .seconds(1))
                        guard !Task.isCancelled else { return }
                        let didSave = await viewModel.updateNotes(newValue, for: saved.id)
                        guard !Task.isCancelled else { return }
                        notesSaveState = didSave ? .saved : .failed
                        if didSave {
                            try? await Task.sleep(for: .seconds(1.4))
                            guard !Task.isCancelled else { return }
                            notesSaveState = .idle
                        }
                    }
                }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Research Sessions

    private var researchSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Research Sessions")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                        .tracking(2.1)
                        .foregroundColor(RC.muted)
                        .textCase(.uppercase)
                    Text("Pick up prior chats with Rena when you want to keep the thread going.")
                        .font(.custom("PlusJakartaSans-Regular", size: 12))
                        .foregroundColor(RC.muted)
                }
                Spacer()
                if loadingConversations {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(RC.primary)
                } else if !linkedConversations.isEmpty {
                    Text("\(linkedConversations.count)")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                        .foregroundColor(RC.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RC.primarySoft)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 18)

            if linkedConversations.isEmpty && !loadingConversations {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No sessions yet")
                        .font(.custom("Manrope", size: 19))
                        .fontWeight(.bold)
                        .foregroundColor(RC.text)
                    Text("Ask Rena about this procedure and your saved conversations will appear here for easy follow-up.")
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundColor(RC.muted)
                        .lineSpacing(3)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(22)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(RC.border, lineWidth: 1))
                .padding(.horizontal, 18)
            } else if !linkedConversations.isEmpty {
                VStack(spacing: 0) {
                    ForEach(linkedConversations) { conversation in
                        Button {
                            onReopenConversation?(conversation.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(RC.primary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(conversation.title ?? "Research Session")
                                        .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                                        .foregroundColor(RC.text)
                                        .lineLimit(1)
                                    Text(Self.sessionDateFormatter.string(from: conversation.updatedAt))
                                        .font(.custom("PlusJakartaSans-Regular", size: 11))
                                        .foregroundColor(RC.muted)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(RC.muted.opacity(0.5))
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                        .disabled(onReopenConversation == nil)
                        .opacity(onReopenConversation == nil ? 0.55 : 1)

                        if conversation.id != linkedConversations.last?.id {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(22)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(RC.border, lineWidth: 1))
                .padding(.horizontal, 18)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - CTA Buttons

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            Button {
                let msg = "I'm researching \(procedure.name) and I have some questions about it."
                onNavigateToChat?(msg, saved.id)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 15))
                    Text("Ask Rena About \(procedure.name)")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RC.primary)
                .cornerRadius(18)
                .shadow(color: RC.shadow, radius: 10, x: 0, y: 4)
            }
            .disabled(onNavigateToChat == nil)
            .opacity(onNavigateToChat == nil ? 0.55 : 1)
        }
        .padding(.horizontal, 18)
    }

    private var exportPayloadText: String {
        let exported = viewModel.exportText(for: currentSaved.id)
        if !exported.isEmpty {
            return exported
        }

        var lines: [String] = []
        lines.append("Consultation Prep: \(procedure.name)")
        lines.append(String(repeating: "—", count: 40))

        if !currentSaved.questions.isEmpty {
            lines.append("")
            lines.append("My Questions:")
            currentSaved.questions.enumerated().forEach { idx, question in
                lines.append("  \(idx + 1). \(question)")
            }
        }

        if let notes = currentSaved.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            lines.append("")
            lines.append("Notes:")
            lines.append(notes)
        }

        lines.append("")
        lines.append("Prepared with Rena Aesthetic Lab")
        return lines.joined(separator: "\n")
    }

    private var notesSaveStatusText: String {
        switch notesSaveState {
        case .idle:
            return "Autosaves"
        case .saving:
            return "Saving..."
        case .saved:
            return "Saved"
        case .failed:
            return "Couldn't save"
        }
    }

    private var notesSaveStatusColor: Color {
        switch notesSaveState {
        case .idle:
            return RC.muted
        case .saving, .saved:
            return RC.primary
        case .failed:
            return Color(hex: "#A85555")
        }
    }
}
