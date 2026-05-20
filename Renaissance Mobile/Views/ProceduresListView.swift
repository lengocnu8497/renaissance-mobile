//
//  ProceduresListView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

private enum PLV {
    static let bg          = Color(hex: "#EEEEFF")
    static let surface     = Color(hex: "#FAFAFF")
    static let text        = Color(hex: "#1E1B4B")
    static let muted       = Color(hex: "#7B6FC0")
    static let primary     = Color(hex: "#6C63FF")
    static let primaryInk  = Color(hex: "#2D2575")
    static let navBtn      = Color(hex: "#EEEEFF")
    static let shadow      = Color(hex: "#6C63FF").opacity(0.08)
}

struct ProceduresListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @State private var viewModel = ProceduresViewModel()
    @State private var selectedProcedure: Procedure?
    @State private var optimisticSavedStates: [UUID: Bool] = [:]
    @State private var savingProcedureIds: Set<UUID> = []
    private let initialSavedIds: Set<UUID>
    private let researchViewModel: ResearchViewModel?
    var onBackButtonTapped: (() -> Void)?
    var onNavigateToChat: ((String, Procedure?) -> Void)?
    var onSaveProcedure: ((Procedure) async -> Void)?
    var isSavedProcedure: ((UUID) -> Bool)?

    init(
        initialSavedIds: Set<UUID> = [],
        researchViewModel: ResearchViewModel? = nil,
        onBackButtonTapped: (() -> Void)? = nil,
        onNavigateToChat: ((String, Procedure?) -> Void)? = nil,
        onSaveProcedure: ((Procedure) async -> Void)? = nil,
        isSavedProcedure: ((UUID) -> Bool)? = nil
    ) {
        self.initialSavedIds = initialSavedIds
        self.researchViewModel = researchViewModel
        self.onBackButtonTapped = onBackButtonTapped
        self.onNavigateToChat = onNavigateToChat
        self.onSaveProcedure = onSaveProcedure
        self.isSavedProcedure = isSavedProcedure
    }

    let filters = ["All", "Face", "Body", "Skin", "Injectables", "Non-Surgical", "Surgical"]

    private var displayedProcedures: [Procedure] {
        viewModel.filtered(by: selectedFilter, searchText: searchText)
    }

    var body: some View {
        ZStack {
            PLV.bg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                searchBar
                filterChips
                proceduresList
                Spacer()
            }
            .onAppear {
                Task { await viewModel.fetchProcedures() }
            }

            floatingButton
        }
        .navigationBarHidden(true)
        .navigationDestination(item: $selectedProcedure) { procedure in
            ProcedureDetailView(
                procedure: procedure,
                allProcedures: viewModel.procedures,
                onNavigateToChat: { msg, proc in onNavigateToChat?(msg, proc) },
                onSaveProcedure: { proc in
                    toggleSave(for: proc)
                },
                isSaved: isProcedureSaved(procedure.id),
                isSavedProcedure: { isProcedureSaved($0) }
            )
        }
    }

    // MARK: - Subviews
    private var header: some View {
        HStack(spacing: 0) {
            Button(action: {
                if let onBackButtonTapped = onBackButtonTapped {
                    onBackButtonTapped()
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(PLV.primaryInk)
                    .frame(width: 36, height: 36)
                    .background(Color.white, in: Circle())
                    .shadow(color: PLV.shadow, radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text("Explore Procedures")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                    .foregroundColor(PLV.text)
            }

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(PLV.muted)

            TextField("Search procedures...", text: $searchText)
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundColor(PLV.text)
                .tint(PLV.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(PLV.navBtn)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.md) {
                ForEach(filters, id: \.self) { filter in
                    FilterChipView(
                        title: filter,
                        isSelected: selectedFilter == filter,
                        action: { selectedFilter = filter }
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(.bottom, Theme.Spacing.lg)
    }

    private var proceduresList: some View {
        Group {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: PLV.primary))
                    Spacer()
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: Theme.Spacing.md) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(PLV.muted)
                    Text(error)
                        .font(.system(size: 15))
                        .foregroundColor(PLV.muted)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.xl)
            } else if displayedProcedures.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(PLV.muted)
                    Text(searchText.isEmpty ? "No procedures in this category yet." : "No results for \"\(searchText)\"")
                        .font(.system(size: 15))
                        .foregroundColor(PLV.muted)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.xl)
            } else {
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        ForEach(displayedProcedures) { procedure in
                            ProcedureListItemView(
                                procedure: procedure,
                                isSaved: isProcedureSaved(procedure.id),
                                onOpenDetails: {
                                    selectedProcedure = procedure
                                },
                                onAskRena: {
                                    onNavigateToChat?("Help me explore \(procedure.name) and decide whether it fits my goals.", procedure)
                                },
                                onToggleSave: {
                                    toggleSave(for: procedure)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, 120)
                }
            }
        }
    }

    private var floatingButton: some View {
        VStack {
            Spacer()
            Button {
                onNavigateToChat?("I'd like help exploring procedures and finding the right treatment for me.", nil)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Chat with a Concierge")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(PLV.primary)
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#6C63FF").opacity(0.35), radius: 10, x: 0, y: 4)
            }
            .padding(.bottom, 28)
        }
    }

    private func isProcedureSaved(_ procedureId: UUID) -> Bool {
        if let optimisticValue = optimisticSavedStates[procedureId] {
            return optimisticValue
        }
        if let researchViewModel {
            return researchViewModel.isSaved(procedureId)
        }
        return isSavedProcedure?(procedureId) ?? initialSavedIds.contains(procedureId)
    }

    private func toggleSave(for procedure: Procedure) {
        guard !savingProcedureIds.contains(procedure.id) else {
            print("[ProcedureSave][List] Ignoring duplicate tap for \(procedure.name) id=\(procedure.id)")
            return
        }

        let nextSavedState = !isProcedureSaved(procedure.id)
        print("[ProcedureSave][List] toggleSave tapped for \(procedure.name) id=\(procedure.id) currentSaved=\(!nextSavedState) nextSaved=\(nextSavedState)")
        optimisticSavedStates[procedure.id] = nextSavedState

        savingProcedureIds.insert(procedure.id)
        print("[ProcedureSave][List] Starting async save task for \(procedure.name) id=\(procedure.id)")

        Task {
            print("[ProcedureSave][List] Entered async save task for \(procedure.name) id=\(procedure.id)")
            if let researchViewModel {
                await researchViewModel.toggleSave(procedure)
            } else if let onSaveProcedure {
                await onSaveProcedure(procedure)
            } else {
                print("[ProcedureSave][List] Missing save handler for \(procedure.name) id=\(procedure.id)")
            }
            await MainActor.run {
                print("[ProcedureSave][List] Async save task completed for \(procedure.name) id=\(procedure.id); clearing optimistic state")
                savingProcedureIds.remove(procedure.id)
                optimisticSavedStates.removeValue(forKey: procedure.id)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProceduresListView()
    }
}
