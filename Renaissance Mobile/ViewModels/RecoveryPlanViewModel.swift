//
//  RecoveryPlanViewModel.swift
//  Renaissance Mobile
//

import Foundation
import Observation

@MainActor
@Observable
final class RecoveryPlanViewModel {
    var plan: PersonalizedRecoveryPlan?
    var isLoading = false
    var errorMessage: String?
    var isLocked: Bool
    var lastLoadedAt: Date?

    private let service: RecoveryPlanService

    init(
        service: RecoveryPlanService? = nil,
        isLocked: Bool = true
    ) {
        self.service = service ?? RecoveryPlanService()
        self.isLocked = isLocked
    }

    var hasPlan: Bool {
        plan != nil
    }

    var currentPhase: RecoveryPlanPhase? {
        plan?.currentPhase
    }

    var personalizationSummary: [String] {
        plan?.personalizationSummary ?? []
    }

    func load(
        journalViewModel: JournalViewModel? = nil,
        forceRefresh: Bool = false
    ) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if forceRefresh {
                plan = try await service.generatePlan(
                    journalViewModel: journalViewModel,
                    forceRefresh: true
                )
            } else {
                plan = try await service.loadOrGeneratePlan(
                    journalViewModel: journalViewModel
                )
            }
            lastLoadedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh(journalViewModel: JournalViewModel? = nil) async {
        await load(journalViewModel: journalViewModel, forceRefresh: true)
    }

    func setLocked(_ locked: Bool) {
        isLocked = locked
    }
}
