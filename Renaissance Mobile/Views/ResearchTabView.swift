//
//  ResearchTabView.swift
//  Renaissance Mobile
//
//  Pre-Procedure Mode — save procedures you're researching,
//  track questions, and store consultation notes.
//

import SwiftUI

struct ResearchTabView: View {
    @State private var viewModel = ResearchViewModel()
    @State private var proceduresViewModel = ProceduresViewModel()
    @State private var selectedProcedure: Procedure?
    @State private var showExploreSheet = false
    @State private var selectedSavedForDetail: SavedProcedure?
    var onNavigateToChat: ((String, Procedure?, UUID?) -> Void)?
    var onReopenConversation: ((UUID) -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.pageBg.ignoresSafeArea()

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
                    onSaveProcedure: { proc in
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
                        onBackButtonTapped: { showExploreSheet = false },
                        onNavigateToChat: { msg, proc in
                            showExploreSheet = false
                            onNavigateToChat?(msg, proc, nil)
                        },
                        onSaveProcedure: { proc in
                            Task { await viewModel.toggleSave(proc) }
                        }
                    )
                }
            }
            .task {
                await viewModel.load()
                await proceduresViewModel.fetchProcedures()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Research")
                        .font(.system(size: 30, weight: .regular, design: .serif))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("Procedures you're exploring")
                        .font(.custom("Outfit-Light", size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                Spacer()
                Button {
                    showExploreSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Theme.Colors.primary)
                        .clipShape(Circle())
                        .shadow(color: Theme.Shadow.button.color, radius: 6, x: 0, y: 3)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 60)
        .padding(.bottom, 18)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView()
                .tint(Theme.Colors.primary)
            Spacer()
        } else if viewModel.savedProcedures.isEmpty {
            emptyState
        } else {
            savedList
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            // Decorative icon
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "bookmark")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(Theme.Colors.primary)
            }

            VStack(spacing: 8) {
                Text("Start Your Research")
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("Save procedures you're considering.\nTrack your questions before your consultation.")
                    .font(.custom("Outfit-Light", size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button {
                showExploreSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("Explore Procedures")
                        .font(.custom("Outfit-SemiBold", size: 15))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Theme.Gradients.hero)
                .cornerRadius(14)
                .shadow(color: Theme.Shadow.button.color, radius: 8, x: 0, y: 4)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Saved List

    private var savedList: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(viewModel.savedProcedures) { saved in
                    if let proc = viewModel.procedure(for: saved) {
                        savedCard(saved: saved, procedure: proc)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 100)
        }
    }

    private func savedCard(saved: SavedProcedure, procedure: Procedure) -> some View {
        Button {
            selectedSavedForDetail = saved
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Top row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(procedure.category.uppercased())
                            .font(.custom("Outfit-SemiBold", size: 9))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text(procedure.name)
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.primary)
                }

                // Recovery tag + surgical badge
                HStack(spacing: 8) {
                    if !procedure.recoveryDurationLabel.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(procedure.recoveryDurationLabel)
                                .font(.custom("Outfit-Regular", size: 11))
                        }
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.primary.opacity(0.06))
                        .clipShape(Capsule())
                    }

                    Text(procedure.isSurgical ? "Surgical" : "Non-Surgical")
                        .font(.custom("Outfit-Regular", size: 11))
                        .foregroundColor(procedure.isSurgical ? Color(hex: "#EF4444") : Color(hex: "#10B981"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((procedure.isSurgical ? Color(hex: "#EF4444") : Color(hex: "#10B981")).opacity(0.08))
                        .clipShape(Capsule())
                }

                // Questions preview
                if !saved.questions.isEmpty {
                    Divider()
                        .background(Theme.Colors.border)

                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.primary)
                            .padding(.top, 1)
                        Text("\(saved.questions.count) question\(saved.questions.count == 1 ? "" : "s") saved")
                            .font(.custom("Outfit-Regular", size: 12))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }

                // Notes preview
                if let notes = saved.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.custom("Outfit-Light", size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                        .lineSpacing(2)
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.border, lineWidth: 1))
            .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await viewModel.toggleSave(procedure) }
            } label: {
                Label("Remove", systemImage: "bookmark.slash")
            }
        }
    }
}

// MARK: - Saved Procedure Detail (questions + notes + export)

struct SavedProcedureDetailView: View {
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
    @State private var isEditingNotes = false
    @State private var notesSaveTask: Task<Void, Never>?
    @State private var linkedConversations: [ChatConversation] = []
    @State private var loadingConversations = false
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

    var body: some View {
        ZStack(alignment: .top) {
            Theme.Colors.pageBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Spacer for nav bar
                    Color.clear.frame(height: 100)

                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text(procedure.category.uppercased())
                            .font(.custom("Outfit-SemiBold", size: 10))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text(procedure.name)
                            .font(.system(size: 28, weight: .light, design: .serif))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                    // Questions section
                    questionsSection

                    // Notes section
                    notesSection

                    // Research sessions section
                    researchSessionsSection

                    // CTA buttons
                    ctaButtons
                        .padding(.bottom, 40)
                }
            }

            // Nav bar
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
                    exportText = viewModel.exportText(for: saved.id)
                    showShareSheet = true
                } label: {
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.Colors.textPrimary)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 56)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [exportText])
        }
        .task {
            await viewModel.refresh(savedId: saved.id)
            loadingConversations = true
            linkedConversations = await viewModel.fetchConversations(for: currentSaved.conversationIds)
            loadingConversations = false
        }
    }

    // MARK: - Questions

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Questions")
                    .font(.custom("Outfit-SemiBold", size: 15))
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                Text("\(currentSaved.questions.count)")
                    .font(.custom("Outfit-SemiBold", size: 12))
                    .foregroundColor(Theme.Colors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)

            // Add question input
            HStack(spacing: 10) {
                TextField("Add a question...", text: $newQuestion)
                    .font(.custom("Outfit-Regular", size: 14))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .focused($questionFieldFocused)
                    .onSubmit { submitQuestion() }

                Button { submitQuestion() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(newQuestion.isEmpty ? Theme.Colors.textSecondary : Theme.Colors.primary)
                }
                .disabled(newQuestion.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.border, lineWidth: 1))
            .padding(.horizontal, 20)

            if currentSaved.questions.isEmpty {
                Text("No questions yet. Add the questions you want to ask your surgeon.")
                    .font(.custom("Outfit-Light", size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(currentSaved.questions.enumerated()), id: \.offset) { idx, question in
                        HStack(alignment: .top, spacing: 10) {
                            Text("·")
                                .font(.custom("Outfit-SemiBold", size: 18))
                                .foregroundColor(Theme.Colors.primary)
                                .offset(y: -2)
                            Text(question)
                                .font(.custom("Outfit-Regular", size: 14))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button {
                                Task { await viewModel.removeQuestion(at: idx, from: saved.id) }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .padding(6)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)

                        if idx < currentSaved.questions.count - 1 {
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.border, lineWidth: 1))
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 24)
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
            Text("Consultation Notes")
                .font(.custom("Outfit-SemiBold", size: 15))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.horizontal, 20)

            TextEditor(text: $notes)
                .font(.custom("Outfit-Light", size: 14))
                .foregroundColor(Theme.Colors.textPrimary)
                .frame(minHeight: 100)
                .padding(12)
                .background(Color.white)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.border, lineWidth: 1))
                .padding(.horizontal, 20)
                .onChange(of: notes) { _, newValue in
                    notesSaveTask?.cancel()
                    notesSaveTask = Task {
                        try? await Task.sleep(for: .seconds(1))
                        guard !Task.isCancelled else { return }
                        await viewModel.updateNotes(newValue, for: saved.id)
                    }
                }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Research Sessions

    private var researchSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Research Sessions")
                    .font(.custom("Outfit-SemiBold", size: 15))
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                if loadingConversations {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(Theme.Colors.primary)
                } else if !linkedConversations.isEmpty {
                    Text("\(linkedConversations.count)")
                        .font(.custom("Outfit-SemiBold", size: 12))
                        .foregroundColor(Theme.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)

            if linkedConversations.isEmpty && !loadingConversations {
                Text("Chat sessions with Rena about this procedure will appear here.")
                    .font(.custom("Outfit-Light", size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 20)
            } else if !linkedConversations.isEmpty {
                VStack(spacing: 0) {
                    ForEach(linkedConversations) { conversation in
                        Button {
                            onReopenConversation?(conversation.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.Colors.primary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(conversation.title ?? "Research Session")
                                        .font(.custom("Outfit-SemiBold", size: 13))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .lineLimit(1)
                                    Text(Self.sessionDateFormatter.string(from: conversation.updatedAt))
                                        .font(.custom("Outfit-Regular", size: 11))
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)

                        if conversation.id != linkedConversations.last?.id {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.border, lineWidth: 1))
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - CTA Buttons

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            // Ask Rena about this procedure
            Button {
                let msg = "I'm researching \(procedure.name) and I have some questions about it."
                onNavigateToChat?(msg, saved.id)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 15))
                    Text("Ask Rena About \(procedure.name)")
                        .font(.custom("Outfit-SemiBold", size: 14))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.Gradients.hero)
                .cornerRadius(14)
                .shadow(color: Theme.Shadow.button.color, radius: 6, x: 0, y: 3)
            }

            // Export
            Button {
                exportText = viewModel.exportText(for: saved.id)
                showShareSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15))
                    Text("Export Questions & Notes")
                        .font(.custom("Outfit-SemiBold", size: 14))
                }
                .foregroundColor(Theme.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.Colors.primary.opacity(0.08))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
    }
}
