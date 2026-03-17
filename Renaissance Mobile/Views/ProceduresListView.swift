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
    var onBackButtonTapped: (() -> Void)?

    let filters = ["Face", "Body", "Skin", "Injectables", "Non-Surgical", "Surgical"]
    let procedures = ProceduresListView.mockProcedures

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

            floatingButton
        }
        .navigationBarHidden(true)
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
                        action: {
                            selectedFilter = filter
                        }
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(.bottom, Theme.Spacing.lg)
    }

    private var proceduresList: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                ForEach(procedures) { procedure in
                    ProcedureListItemView(procedure: procedure)
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.medium)
                        .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius, x: Theme.Shadow.card.x, y: Theme.Shadow.card.y)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, 120)
        }
    }

    private var floatingButton: some View {
        VStack {
            Spacer()

            Button(action: {}) {
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

    // MARK: - Mock Data
    static let mockProcedures = [
        Procedure(name: "Microneedling", description: "For skin rejuvenation and texture improvement", category: "Non-Surgical", imageName: nil),
        Procedure(name: "Lip Fillers", description: "Enhance volume and define lip shape", category: "Injectable", imageName: nil),
        Procedure(name: "Laser Hair Removal", description: "Permanent reduction of unwanted hair", category: "Laser", imageName: nil),
        Procedure(name: "Chemical Peel", description: "Improves skin tone and reduces blemishes", category: "Skin", imageName: nil),
        Procedure(name: "Botox", description: "Reduces fine lines and wrinkles", category: "Injectable", imageName: nil),
        Procedure(name: "Dermal Fillers", description: "Restore volume and smooth wrinkles", category: "Injectable", imageName: nil)
    ]
}

#Preview {
    ProceduresListView()
}
