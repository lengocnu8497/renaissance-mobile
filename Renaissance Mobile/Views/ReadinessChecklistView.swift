//
//  ReadinessChecklistView.swift
//  Renaissance Mobile
//

import SwiftUI
import Supabase

struct ReadinessChecklistView: View {
    @State private var viewModel: ReadinessChecklistViewModel
    @State private var showProcedurePicker = false
    @State private var showShareSheet = false
    @State private var shareText = ""
    @Environment(\.dismiss) private var dismiss

    // If launched with a specific procedure pre-selected
    init(procedureId: String? = nil, userId: String = "") {
        _viewModel = State(initialValue: ReadinessChecklistViewModel(userId: userId, procedureId: procedureId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundProcedures.ignoresSafeArea()

                if viewModel.checklist == nil {
                    procedurePickerPrompt
                } else {
                    checklistContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showProcedurePicker) {
                ProcedurePickerSheet(
                    selectedId: viewModel.selectedProcedureId,
                    onSelect: { id in
                        viewModel.selectedProcedureId = id
                        showProcedurePicker = false
                    }
                )
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(text: shareText)
            }
        }
        .task {
            await loadUserId()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Readiness Check")
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
        if viewModel.checklist != nil {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    shareText = viewModel.shareText()
                    showShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.primaryHome)
                }
            }
        }
    }

    // MARK: - Procedure Picker Prompt

    private var procedurePickerPrompt: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 56))
                .foregroundColor(Theme.Colors.primaryHome.opacity(0.5))

            VStack(spacing: Theme.Spacing.sm) {
                Text("Choose a Procedure")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.Colors.textProceduresPrimary)

                Text("Select the procedure you're preparing for to see your personalized readiness checklist.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.Colors.textProceduresSubtle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxl)
            }

            Button(action: { showProcedurePicker = true }) {
                Text("Select Procedure")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.Colors.primaryHome)
                    .cornerRadius(Theme.CornerRadius.medium)
            }
            .padding(.horizontal, Theme.Spacing.xxl)

            Spacer()
        }
    }

    // MARK: - Checklist Content

    private var checklistContent: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                procedureHeader
                progressCard
                sectionsBlock
                disclaimerBlock
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, 40)
        }
    }

    private var procedureHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.checklist?.displayName ?? "")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.Colors.textProceduresPrimary)

                if let category = viewModel.checklist?.category {
                    Text(category)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textProceduresSubtle)
                }
            }

            Spacer()

            Button(action: { showProcedurePicker = true }) {
                Text("Change")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.Colors.primaryHome)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.primaryHome.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.full)
            }
        }
        .padding(.top, Theme.Spacing.lg)
    }

    private var progressCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Text("Preparation Progress")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.textProceduresPrimary)
                Spacer()
                Text("\(viewModel.actionableCompletedCount) of \(viewModel.actionableTotalCount) steps")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textProceduresSubtle)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.borderLight)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(
                            width: max(0, geo.size.width * CGFloat(
                                viewModel.actionableTotalCount > 0
                                    ? Double(viewModel.actionableCompletedCount) / Double(viewModel.actionableTotalCount)
                                    : 0
                            )),
                            height: 6
                        )
                        .animation(.easeInOut(duration: 0.3), value: viewModel.actionableCompletedCount)
                }
            }
            .frame(height: 6)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius, x: Theme.Shadow.card.x, y: Theme.Shadow.card.y)
    }

    private var progressColor: Color {
        let pct = viewModel.actionableTotalCount > 0
            ? Double(viewModel.actionableCompletedCount) / Double(viewModel.actionableTotalCount)
            : 0
        if pct < 0.5 { return Theme.Colors.primaryHome.opacity(0.6) }
        if pct < 1.0 { return Theme.Colors.primaryHome }
        return Color.green
    }

    private var sectionsBlock: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(viewModel.checklist?.sections ?? [], id: \.id) { section in
                ChecklistSectionView(
                    section: section,
                    isExpanded: viewModel.isSectionExpanded(section.id),
                    isCompleted: { viewModel.isCompleted($0) },
                    onToggle: { viewModel.toggle($0) },
                    onToggleExpand: { viewModel.toggleSection(section.id) }
                )
            }
        }
    }

    // MARK: - Disclaimer

    private var disclaimerBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textProceduresSubtle)
                Text("Medical Disclaimer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.textProceduresSubtle)
            }

            Text("This checklist is for general informational purposes only and does not constitute medical advice, diagnosis, or treatment recommendations. Content is derived from publicly available clinical guidelines published by the American Society of Plastic Surgeons (ASPS) and American Academy of Dermatology (AAD). Individual circumstances vary — always consult a licensed, board-certified provider before undergoing any cosmetic procedure. Renaissance is not liable for decisions made based on this information.")
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

    // MARK: - Load User ID

    private func loadUserId() async {
        if let id = try? await supabase.auth.session.user.id {
            viewModel = ReadinessChecklistViewModel(
                userId: id.uuidString,
                procedureId: viewModel.selectedProcedureId
            )
        }
    }
}

// MARK: - Procedure Picker Sheet

private struct ProcedurePickerSheet: View {
    let selectedId: String?
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [ProcedureChecklist] {
        if searchText.isEmpty { return ReadinessData.all }
        return ReadinessData.all.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { procedure in
                    Button(action: { onSelect(procedure.id) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(procedure.displayName)
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.textProceduresPrimary)
                                Text(procedure.category)
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.Colors.textProceduresSubtle)
                            }
                            Spacer()
                            if procedure.id == selectedId {
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
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
