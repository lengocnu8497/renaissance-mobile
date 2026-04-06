//
//  ProceduresListView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI

private enum PLV {
    static let text = Color(hex: "#1F261D")
    static let muted = Color(hex: "#687064")
    static let primary = Color(hex: "#516048")
    static let primaryInk = Color(hex: "#314030")
    static let lightGlass = Color.white.opacity(0.78)
    static let lightGlassStrong = Color(hex: "#FBFCF8").opacity(0.94)
    static let stroke = Color.white.opacity(0.72)
    static let shadow = Color(red: 90/255, green: 103/255, blue: 80/255).opacity(0.10)
}

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
                isSaved: savedProcedureIds.contains(procedure.id),
                isSavedProcedure: { savedProcedureIds.contains($0) }
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
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PLV.primaryInk)
                    .frame(width: 44, height: 44)
                    .background(PLV.lightGlass, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PLV.stroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Explore Procedures")
                .font(.custom("Manrope", size: 26))
                .fontWeight(.heavy)
                .foregroundColor(PLV.text)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.sm)
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
                            ProcedureListItemView(
                                procedure: procedure,
                                isSaved: savedProcedureIds.contains(procedure.id),
                                onOpenDetails: {
                                    selectedProcedure = procedure
                                },
                                onAskRena: {
                                    onNavigateToChat?("Help me explore \(procedure.name) and decide whether it fits my goals.", procedure)
                                },
                                onToggleSave: {
                                    if savedProcedureIds.contains(procedure.id) {
                                        savedProcedureIds.remove(procedure.id)
                                    } else {
                                        savedProcedureIds.insert(procedure.id)
                                    }
                                    onSaveProcedure?(procedure)
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
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Chat with a Concierge")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                }
                .foregroundColor(.white)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.lg)
                .background(PLV.primary)
                .cornerRadius(28)
                .shadow(color: PLV.shadow, radius: 14, x: 0, y: 8)
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
