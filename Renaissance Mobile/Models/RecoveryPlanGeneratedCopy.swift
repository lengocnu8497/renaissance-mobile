//
//  RecoveryPlanGeneratedCopy.swift
//  Renaissance Mobile
//

import Foundation

struct RecoveryPlanGeneratedCopy: Codable, Equatable {
    let summary: String
    let focusAreas: [String]

    var normalized: RecoveryPlanGeneratedCopy {
        RecoveryPlanGeneratedCopy(
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            focusAreas: focusAreas
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    var isMeaningfullyEmpty: Bool {
        normalized.summary.isEmpty || normalized.focusAreas.isEmpty
    }
}

