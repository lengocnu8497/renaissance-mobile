//
//  ProceduresHubView.swift
//  Renaissance Mobile
//

import SwiftUI

struct ProceduresHubView: View {
    var onBackButtonTapped: (() -> Void)?

    @State private var navigateToChecklist = false
    @State private var navigateToCostEstimator = false
    @State private var navigateToProceduresList = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundProcedures.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        featureCards
                        proceduresQuickLink
                    }
                    .padding(.bottom, 100)
                }
                .navigationBarHidden(true)
            }
            .navigationDestination(isPresented: $navigateToChecklist) {
                ReadinessChecklistView()
            }
            .navigationDestination(isPresented: $navigateToCostEstimator) {
                CostEstimatorView()
            }
            .navigationDestination(isPresented: $navigateToProceduresList) {
                ProceduresListView(onBackButtonTapped: {
                    navigateToProceduresList = false
                })
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Procedure Tools")
                .font(Theme.Typography.homeHeader)
                .foregroundColor(Theme.Colors.textProceduresPrimary)

            Text("Everything you need to prepare and plan.")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(Theme.Colors.textProceduresSubtle)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.xxl)
        .padding(.bottom, Theme.Spacing.xl)
    }

    // MARK: - Feature Cards

    private var featureCards: some View {
        VStack(spacing: Theme.Spacing.lg) {
            FeatureToolCard(
                icon: "checklist",
                iconColor: Theme.Colors.primaryHome,
                title: "Readiness Check",
                subtitle: "Candidacy, pre-care, what to expect, and red flags — for 10 procedures.",
                badgeText: nil,
                action: { navigateToChecklist = true }
            )

            FeatureToolCard(
                icon: "dollarsign.circle",
                iconColor: Color(hex: "#2B8A3E"),
                title: "Cost Estimator",
                subtitle: "See low, average, and high price ranges adjusted for your region.",
                badgeText: "New",
                action: { navigateToCostEstimator = true }
            )
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Procedures Quick Link

    private var proceduresQuickLink: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Browse Procedures")
                .font(Theme.Typography.sectionTitle)
                .foregroundColor(Theme.Colors.textProceduresPrimary)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.xl)

            Button(action: { navigateToProceduresList = true }) {
                HStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.primaryProcedures)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.primaryProcedures.opacity(0.1))
                        .cornerRadius(Theme.CornerRadius.medium)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Explore All Procedures")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.Colors.textProceduresPrimary)
                        Text("Face, Body, Injectables, Skin & more")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textProceduresSubtle)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textProceduresSubtle)
                }
                .padding(Theme.Spacing.lg)
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius, x: Theme.Shadow.card.x, y: Theme.Shadow.card.y)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
}

// MARK: - Feature Tool Card

struct FeatureToolCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let badgeText: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.lg) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
                    .frame(width: 52, height: 52)
                    .background(iconColor.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.medium)

                // Text
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.Colors.textProceduresPrimary)

                        if let badge = badgeText {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(iconColor)
                                .cornerRadius(Theme.CornerRadius.full)
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textProceduresSubtle)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textProceduresSubtle)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.large)
            .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius, x: Theme.Shadow.card.x, y: Theme.Shadow.card.y)
        }
        .buttonStyle(.plain)
    }
}
