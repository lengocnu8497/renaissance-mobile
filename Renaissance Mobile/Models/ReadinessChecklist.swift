//
//  ReadinessChecklist.swift
//  Renaissance Mobile
//

import Foundation

// MARK: - Models

struct ChecklistItem: Identifiable, Codable {
    let id: String
    let text: String
    let isWarning: Bool // true = red flag styling

    init(id: String, text: String, isWarning: Bool = false) {
        self.id = id
        self.text = text
        self.isWarning = isWarning
    }
}

enum ChecklistSectionType: String, Codable, CaseIterable {
    case candidacy   = "Am I a Good Candidate?"
    case preCare     = "Before Your Appointment"
    case whatToExpect = "What to Expect"
    case redFlags    = "Red Flags — Contact Your Provider"

    var systemImage: String {
        switch self {
        case .candidacy:    return "person.fill.checkmark"
        case .preCare:      return "calendar.badge.clock"
        case .whatToExpect: return "clock.fill"
        case .redFlags:     return "exclamationmark.triangle.fill"
        }
    }

    var isWarningSection: Bool {
        self == .redFlags
    }
}

struct ChecklistSection: Identifiable {
    let id: ChecklistSectionType
    let items: [ChecklistItem]

    var title: String { id.rawValue }
    var systemImage: String { id.systemImage }
    var isWarningSection: Bool { id.isWarningSection }
}

struct ProcedureChecklist: Identifiable {
    let id: String          // matches procedure name slug e.g. "botox"
    let displayName: String
    let category: String
    let sections: [ChecklistSection]

    func section(_ type: ChecklistSectionType) -> ChecklistSection? {
        sections.first { $0.id == type }
    }

    var allItemIds: [String] {
        sections.flatMap { $0.items.map { $0.id } }
    }
}
