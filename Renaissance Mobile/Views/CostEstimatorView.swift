//
//  CostEstimatorView.swift
//  Renaissance Mobile
//

import SwiftUI
import Supabase

struct CostEstimatorView: View {
    @State private var viewModel = CostEstimatorViewModel()
    @State private var showProcedurePicker = false
    @State private var selectedCategory = "All"
    @Environment(\.dismiss) private var dismiss

    private let categories = ["All"] + ProcedurePricingData.categories

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundProcedures.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        regionSection
                        procedureSection
                        if viewModel.selectedPricing != nil {
                            sessionSection
                            calculateButton
                        }
                        disclaimerBlock
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, 40)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
            }
        }
        .sheet(isPresented: $viewModel.showResult) {
            if let result = viewModel.result {
                CostEstimatorResultView(result: result)
            }
        }
        .sheet(isPresented: $showProcedurePicker) {
            PricingProcedurePickerSheet(
                selectedId: viewModel.selectedPricingId,
                onSelect: { pricing in
                    viewModel.selectProcedure(pricing)
                    showProcedurePicker = false
                }
            )
        }
        .task {
            await loadZipCode()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Cost Estimator")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Theme.Colors.textProceduresPrimary)
        }
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.Colors.textProceduresPrimary)
            }
        }
    }

    // MARK: - Region Section

    private var regionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("Your Region", systemImage: "location")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textProceduresPrimary)

            Menu {
                ForEach(PricingRegion.allCases, id: \.self) { region in
                    Button(action: { viewModel.region = region }) {
                        HStack {
                            Text(region.rawValue)
                            if region == viewModel.region {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.region.rawValue)
                        .font(.system(size: 15))
                        .foregroundColor(Theme.Colors.textProceduresPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textProceduresSubtle)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, 14)
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(Theme.Colors.borderLight, lineWidth: 1)
                )
            }

            Text("Prices are adjusted ×\(String(format: "%.2f", viewModel.region.multiplier)) for your region")
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textProceduresSubtle)
        }
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - Procedure Section

    private var procedureSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("Procedure", systemImage: "wand.and.stars")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textProceduresPrimary)

            Button(action: { showProcedurePicker = true }) {
                HStack {
                    if let pricing = viewModel.selectedPricing {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pricing.displayName)
                                .font(.system(size: 15))
                                .foregroundColor(Theme.Colors.textProceduresPrimary)
                            Text(pricing.category)
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textProceduresSubtle)
                        }
                    } else {
                        Text("Select a procedure")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.Colors.textProceduresSubtle)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textProceduresSubtle)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, 14)
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(
                            viewModel.selectedPricing != nil ? Theme.Colors.primaryHome.opacity(0.4) : Theme.Colors.borderLight,
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Session Count Section

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label("Number of Sessions", systemImage: "calendar.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.textProceduresPrimary)
                Spacer()
                if let pricing = viewModel.selectedPricing {
                    Text("Typical: \(pricing.typicalSessions)")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textProceduresSubtle)
                }
            }

            HStack(spacing: Theme.Spacing.xl) {
                Button(action: {
                    if viewModel.sessionCount > 1 { viewModel.sessionCount -= 1 }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(viewModel.sessionCount > 1 ? Theme.Colors.primaryHome : Theme.Colors.borderLight)
                }

                Text("\(viewModel.sessionCount)")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Theme.Colors.textProceduresPrimary)
                    .frame(minWidth: 40)

                Button(action: {
                    if viewModel.sessionCount < 20 { viewModel.sessionCount += 1 }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.Colors.primaryHome)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 14)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.borderLight, lineWidth: 1)
            )

            if let pricing = viewModel.selectedPricing {
                Text(pricing.priceNote)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textProceduresSubtle)
            }
        }
    }

    // MARK: - Calculate Button

    private var calculateButton: some View {
        Button(action: { viewModel.calculate() }) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 18))
                Text("Estimate My Cost")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.Colors.primaryHome)
            .cornerRadius(Theme.CornerRadius.medium)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canCalculate)
    }

    // MARK: - Disclaimer

    private var disclaimerBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textProceduresSubtle)
                Text("Pricing Disclaimer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.textProceduresSubtle)
            }

            Text("Estimates are national averages based on ASPS 2023 Statistics and industry surveys. Actual costs vary significantly by provider, location, technique, and individual treatment plan. Prices reflect provider fees only — facility fees, anesthesia, and follow-up care are additional. Always obtain a personalized quote during a consultation with a board-certified provider. Renaissance does not guarantee accuracy of these estimates.")
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textProceduresSubtle)
                .lineSpacing(3)
        }
        .padding(Theme.Spacing.lg)
        .background(Color(hex: "#F8F8F8"))
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Load Zip

    private func loadZipCode() async {
        if let profile = try? await UserProfileService(supabase: supabase).getUserProfile(),
           let zip = profile.zipCode, !zip.isEmpty {
            viewModel.region = PricingRegion.infer(fromZip: zip)
        }
    }
}

// MARK: - Result Sheet

struct CostEstimatorResultView: View {
    let result: CostEstimateResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    procedureHeader
                    priceRangeCard
                    breakdownCard
                    nextStepsCard
                    resultDisclaimer
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, 40)
            }
            .background(Theme.Colors.backgroundProcedures.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Your Estimate")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.Colors.textProceduresPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.primaryHome)
                }
            }
        }
    }

    private var procedureHeader: some View {
        VStack(spacing: 6) {
            Text(result.procedure.displayName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Theme.Colors.textProceduresPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Label(result.region.rawValue, systemImage: "location")
                Text("·")
                Text("\(result.sessionCount) session\(result.sessionCount > 1 ? "s" : "")")
            }
            .font(.system(size: 13))
            .foregroundColor(Theme.Colors.textProceduresSubtle)
        }
        .padding(.top, Theme.Spacing.xl)
    }

    private var priceRangeCard: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Estimated Total Cost")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textProceduresSubtle)

            Text(result.rangeText)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Theme.Colors.textProceduresPrimary)

            // Visual range bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.Colors.borderLight)
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#2B8A3E").opacity(0.6), Color(hex: "#2B8A3E")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * 0.6, height: 12)
                        .offset(x: geo.size.width * 0.2)

                    // Low marker
                    VStack(spacing: 2) {
                        Circle().fill(Color.white).frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color(hex: "#2B8A3E"), lineWidth: 2))
                        Text("Low").font(.system(size: 9)).foregroundColor(Theme.Colors.textProceduresSubtle)
                    }
                    .offset(x: geo.size.width * 0.2 - 7, y: -2)

                    // Avg marker
                    VStack(spacing: 2) {
                        Circle().fill(Color(hex: "#2B8A3E")).frame(width: 16, height: 16)
                        Text("Avg").font(.system(size: 9, weight: .semibold)).foregroundColor(Theme.Colors.textProceduresPrimary)
                    }
                    .offset(x: geo.size.width * 0.5 - 8, y: -2)

                    // High marker
                    VStack(spacing: 2) {
                        Circle().fill(Color.white).frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color(hex: "#2B8A3E"), lineWidth: 2))
                        Text("High").font(.system(size: 9)).foregroundColor(Theme.Colors.textProceduresSubtle)
                    }
                    .offset(x: geo.size.width * 0.8 - 7, y: -2)
                }
            }
            .frame(height: 36)
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(Theme.Spacing.xl)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.large)
        .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius, x: Theme.Shadow.card.x, y: Theme.Shadow.card.y)
    }

    private var breakdownCard: some View {
        VStack(spacing: 0) {
            resultRow(label: "Low estimate", value: format(result.lowTotal), highlight: false)
            Divider().padding(.leading, Theme.Spacing.lg)
            resultRow(label: "Average estimate", value: format(result.avgTotal), highlight: true)
            Divider().padding(.leading, Theme.Spacing.lg)
            resultRow(label: "High estimate", value: format(result.highTotal), highlight: false)
            Divider().padding(.leading, Theme.Spacing.lg)
            resultRow(label: "Sessions included", value: "\(result.sessionCount)", highlight: false)
            Divider().padding(.leading, Theme.Spacing.lg)
            resultRow(label: "Region modifier", value: "×\(String(format: "%.2f", result.region.multiplier))", highlight: false)
        }
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius, x: Theme.Shadow.card.x, y: Theme.Shadow.card.y)
    }

    private func resultRow(label: String, value: String, highlight: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: highlight ? .semibold : .regular))
                .foregroundColor(highlight ? Theme.Colors.textProceduresPrimary : Theme.Colors.textProceduresSubtle)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: highlight ? .bold : .medium))
                .foregroundColor(highlight ? Color(hex: "#2B8A3E") : Theme.Colors.textProceduresPrimary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, 13)
    }

    private var nextStepsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Next Steps", systemImage: "arrow.right.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textProceduresPrimary)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                nextStepRow(number: "1", text: "Book a consultation to get a personalized quote")
                nextStepRow(number: "2", text: "Ask your provider about package pricing for multiple sessions")
                nextStepRow(number: "3", text: "Check if your provider offers financing (CareCredit, Alphaeon)")
                nextStepRow(number: "4", text: "Remember: prices above don't include facility or anesthesia fees")
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.iconCircleBackground.opacity(0.3))
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func nextStepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Theme.Colors.primaryHome)
                .clipShape(Circle())
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textProceduresPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var resultDisclaimer: some View {
        Text("These estimates are for planning purposes only. Actual costs vary by provider and individual treatment plan. Always verify pricing directly with your provider during a consultation.")
            .font(.system(size: 11))
            .foregroundColor(Theme.Colors.textProceduresSubtle)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.Spacing.lg)
    }

    private func format(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Procedure Picker Sheet

private struct PricingProcedurePickerSheet: View {
    let selectedId: String?
    let onSelect: (ProcedurePricing) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory = "All"

    private var categories: [String] { ["All"] + ProcedurePricingData.categories }

    private var filtered: [ProcedurePricing] {
        var list = ProcedurePricingData.byCategory(selectedCategory)
        if !searchText.isEmpty {
            list = list.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(categories, id: \.self) { cat in
                            FilterChipView(
                                title: cat,
                                isSelected: selectedCategory == cat,
                                action: { selectedCategory = cat }
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                }

                Divider()

                List {
                    ForEach(filtered) { pricing in
                        Button(action: { onSelect(pricing) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(pricing.displayName)
                                        .font(.system(size: 15))
                                        .foregroundColor(Theme.Colors.textProceduresPrimary)
                                    Text("\(formatRange(pricing.lowPrice, pricing.highPrice)) · \(pricing.priceNote)")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.Colors.textProceduresSubtle)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if pricing.id == selectedId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.Colors.primaryHome)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search procedures")
            .navigationTitle("Select Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.primaryHome)
                }
            }
        }
    }

    private func formatRange(_ low: Int, _ high: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        let l = f.string(from: NSNumber(value: low)) ?? "$\(low)"
        let h = f.string(from: NSNumber(value: high)) ?? "$\(high)"
        return "\(l)–\(h)"
    }
}
