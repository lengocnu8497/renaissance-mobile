//
//  ProceduresListView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

struct ProceduresListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedFilter = "Face"
    @State private var viewModel = ProceduresViewModel()
    @State private var selectedProcedure: Procedure?
    @State private var savedProcedureIds: Set<UUID>
    var onBackButtonTapped: (() -> Void)?
    var onNavigateToChat: ((String, Procedure?) -> Void)?
    var onSaveProcedure: ((Procedure) -> Void)?

    init(
        initialSavedIds: Set<UUID> = [],
        onBackButtonTapped: (() -> Void)? = nil,
        onNavigateToChat: ((String, Procedure?) -> Void)? = nil,
        onSaveProcedure: ((Procedure) -> Void)? = nil
    ) {
        self._savedProcedureIds = State(initialValue: initialSavedIds)
        self.onBackButtonTapped = onBackButtonTapped
        self.onNavigateToChat = onNavigateToChat
        self.onSaveProcedure = onSaveProcedure
    }

    let filters = ["Face", "Body", "Skin", "Injectables", "Non-Surgical", "Surgical"]

    private var displayedProcedures: [Procedure] {
        viewModel.filtered(by: selectedFilter, searchText: searchText)
    }

    var body: some View {
        ZStack {
            Theme.Colors.backgroundProcedures
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
                    if savedProcedureIds.contains(proc.id) {
                        savedProcedureIds.remove(proc.id)
                    } else {
                        savedProcedureIds.insert(proc.id)
                    }
                    onSaveProcedure?(proc)
                },
                isSaved: savedProcedureIds.contains(procedure.id)
            )
        }
    }

    // MARK: - Subviews
    private var header: some View {
        HStack {
            Button(action: {
                if let onBackButtonTapped = onBackButtonTapped {
                    onBackButtonTapped()
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 24))
                    .foregroundColor(Theme.Colors.textProceduresPrimary)
                    .frame(width: 48, height: 48)
            }

            Spacer()

            Text("Explore Procedures")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.Colors.textProceduresPrimary)

            Spacer()

            Color.clear.frame(width: 48, height: 48)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
    }

    private var searchBar: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20))
                .foregroundColor(Theme.Colors.textProceduresSubtle)
                .frame(width: 48, height: 56)

            TextField("Search for treatments...", text: $searchText)
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.textProceduresPrimary)
        }
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
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
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.textProceduresPrimary))
                    Spacer()
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: Theme.Spacing.md) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.Colors.textProceduresSubtle)
                    Text(error)
                        .font(.system(size: 15))
                        .foregroundColor(Theme.Colors.textProceduresSubtle)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.xl)
            } else if displayedProcedures.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.Colors.textProceduresSubtle)
                    Text(searchText.isEmpty ? "No procedures in this category yet." : "No results for \"\(searchText)\"")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.Colors.textProceduresSubtle)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.xl)
            } else {
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        ForEach(displayedProcedures) { procedure in
                            Button {
                                selectedProcedure = procedure
                            } label: {
                                ProcedureListItemView(procedure: procedure)
                                    .background(Theme.Colors.cardBackground)
                                    .cornerRadius(Theme.CornerRadius.medium)
                                    .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius, x: Theme.Shadow.card.x, y: Theme.Shadow.card.y)
                            }
                            .buttonStyle(.plain)
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
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 20))
                    Text("Chat with a Concierge")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.lg)
                .background(Theme.Colors.textProceduresPrimary)
                .cornerRadius(28)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    NavigationStack {
        ProceduresListView()
    }
}
