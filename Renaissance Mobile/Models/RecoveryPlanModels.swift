//
//  RecoveryPlanModels.swift
//  Renaissance Mobile
//

import Foundation

struct PersonalizedRecoveryPlan: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let procedureName: String
    let procedureId: String?
    let procedureDate: Date
    let generatedAt: Date
    let planVersion: Int
    let inputHash: String
    let currentPhase: RecoveryPlanPhase
    let phases: [RecoveryPlanPhase]
    let personalizationSummary: [String]
    let disclaimers: [String]
}

struct RecoveryPlanPhase: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let weekStart: Int
    let weekEnd: Int
    let status: RecoveryPlanPhaseStatus
    let summary: String
    let expectations: [String]
    let focusAreas: [String]
    let photoPrompts: [String]
    let providerQuestions: [String]
    let watchFors: [String]
    let encouragement: String?
}

enum RecoveryPlanPhaseStatus: String, Codable, CaseIterable {
    case completed
    case current
    case upcoming
}

struct RecoveryPlanInput: Codable, Equatable {
    let procedureName: String
    let procedureDate: Date
    let daysSinceProcedure: Int
    let currentWeek: Int
    let currentPhaseTitle: String
    let procedureFamily: RecoveryPlanProcedureFamily
    let gender: String?
    let ageRange: String?
    let raceEthnicity: String?
    let aestheticGoals: [String]
    let bodyAreas: [String]
    let proceduresOfInterest: [String]
    let previousProcedures: [String]
    let healthFlags: [String]
    let latestJournalSignals: RecoveryPlanJournalSignals?
}

struct RecoveryPlanJournalSignals: Codable, Equatable {
    let entryCount: Int
    let latestPainLevel: Int?
    let latestSwellingLevel: Int?
    let latestBruisingLevel: Int?
    let latestRednessLevel: Int?
    let weeklySummaryHeadline: String?
    let activeAlerts: [String]
}

enum RecoveryPlanProcedureFamily: String, Codable, CaseIterable, Identifiable {
    case rhinoplasty
    case breastSurgery
    case bodyContouring
    case facialSurgery
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rhinoplasty:
            return "Rhinoplasty"
        case .breastSurgery:
            return "Breast Surgery"
        case .bodyContouring:
            return "Body Contouring"
        case .facialSurgery:
            return "Facial Surgery"
        case .other:
            return "Other"
        }
    }
}

struct RecoveryPlanTimeline: Equatable {
    let procedureFamily: RecoveryPlanProcedureFamily
    let procedureDate: Date
    let daysSinceProcedure: Int
    let currentWeek: Int
    let currentPhase: RecoveryPlanTimelinePhase
    let phases: [RecoveryPlanTimelinePhase]
}

struct RecoveryPlanTimelinePhase: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let weekStart: Int
    let weekEnd: Int
    let status: RecoveryPlanPhaseStatus
    let summary: String

    var isCurrent: Bool {
        status == .current
    }
}
