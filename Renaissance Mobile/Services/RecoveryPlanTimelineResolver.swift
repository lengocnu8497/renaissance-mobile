//
//  RecoveryPlanTimelineResolver.swift
//  Renaissance Mobile
//

import Foundation

struct RecoveryPlanTimelineResolver {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func resolveTimeline(
        procedureName: String,
        procedureDate: Date,
        referenceDate: Date = Date()
    ) -> RecoveryPlanTimeline {
        let family = resolveProcedureFamily(for: procedureName)
        let daysSinceProcedure = max(
            0,
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: procedureDate),
                to: calendar.startOfDay(for: referenceDate)
            ).day ?? 0
        )

        let currentWeek = max(1, (daysSinceProcedure / 7) + 1)
        let basePhases = phaseDefinitions(for: family)

        let resolvedPhases = basePhases.map { definition in
            RecoveryPlanTimelinePhase(
                id: definition.id,
                title: definition.title,
                weekStart: definition.weekStart,
                weekEnd: definition.weekEnd,
                status: status(for: definition, currentWeek: currentWeek),
                summary: definition.summary
            )
        }

        let currentPhase = resolvedPhases.first(where: \.isCurrent) ?? resolvedPhases.last ?? RecoveryPlanTimelinePhase(
            id: "current-phase",
            title: "Current phase",
            weekStart: currentWeek,
            weekEnd: currentWeek,
            status: .current,
            summary: "Continue tracking your healing and watch for meaningful trends."
        )

        return RecoveryPlanTimeline(
            procedureFamily: family,
            procedureDate: procedureDate,
            daysSinceProcedure: daysSinceProcedure,
            currentWeek: currentWeek,
            currentPhase: currentPhase,
            phases: resolvedPhases
        )
    }

    func resolveProcedureFamily(for procedureName: String) -> RecoveryPlanProcedureFamily {
        let normalized = procedureName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalized.contains("rhinoplasty") || normalized.contains("nose") {
            return .rhinoplasty
        }

        if normalized.contains("breast") {
            return .breastSurgery
        }

        if normalized.contains("lipo")
            || normalized.contains("tummy tuck")
            || normalized.contains("body contour")
            || normalized.contains("bbl") {
            return .bodyContouring
        }

        if normalized.contains("facelift")
            || normalized.contains("bleph")
            || normalized.contains("eyelid")
            || normalized.contains("brow lift")
            || normalized.contains("facial") {
            return .facialSurgery
        }

        return .other
    }

    private func status(
        for definition: PhaseDefinition,
        currentWeek: Int
    ) -> RecoveryPlanPhaseStatus {
        if currentWeek < definition.weekStart {
            return .upcoming
        }

        if currentWeek > definition.weekEnd {
            return .completed
        }

        return .current
    }

    private func phaseDefinitions(for family: RecoveryPlanProcedureFamily) -> [PhaseDefinition] {
        switch family {
        case .rhinoplasty:
            return [
                PhaseDefinition(
                    id: "rhino-acute",
                    title: "Days 1-7: protection and swelling management",
                    weekStart: 1,
                    weekEnd: 1,
                    summary: "The focus is rest, splint care, and resisting early judgment while swelling is still high."
                ),
                PhaseDefinition(
                    id: "rhino-early-refinement",
                    title: "Weeks 2-4: visible swelling starts to settle",
                    weekStart: 2,
                    weekEnd: 4,
                    summary: "Bruising often improves here, but the nose can still look uneven or overly swollen from day to day."
                ),
                PhaseDefinition(
                    id: "rhino-mid-refinement",
                    title: "Weeks 5-8: compare trends, not daily changes",
                    weekStart: 5,
                    weekEnd: 8,
                    summary: "This phase is better for weekly photo comparison and follow-up questions about lingering asymmetry."
                ),
                PhaseDefinition(
                    id: "rhino-long-tail",
                    title: "Months 3-12: gradual definition and long-tail refinement",
                    weekStart: 9,
                    weekEnd: 52,
                    summary: "The plan should shift toward patience, milestone tracking, and realistic expectations for final refinement."
                )
            ]

        case .breastSurgery:
            return [
                PhaseDefinition(
                    id: "breast-acute",
                    title: "Days 1-7: soreness, swelling, and support",
                    weekStart: 1,
                    weekEnd: 1,
                    summary: "Support, rest, and movement restrictions matter most in the first week."
                ),
                PhaseDefinition(
                    id: "breast-settling",
                    title: "Weeks 2-6: settling, tightness, and shape transition",
                    weekStart: 2,
                    weekEnd: 6,
                    summary: "Tightness and swelling can still distort shape, so the plan should help the user avoid premature conclusions."
                ),
                PhaseDefinition(
                    id: "breast-softening",
                    title: "Weeks 7-12: softening and clearer positioning",
                    weekStart: 7,
                    weekEnd: 12,
                    summary: "This is where shape assessment becomes more useful and follow-up questions become more specific."
                ),
                PhaseDefinition(
                    id: "breast-refinement",
                    title: "Months 3-6: refinement and outcome review",
                    weekStart: 13,
                    weekEnd: 26,
                    summary: "The roadmap should focus on long-term comfort, scar progress, and result evaluation."
                )
            ]

        case .bodyContouring:
            return [
                PhaseDefinition(
                    id: "body-acute",
                    title: "Days 1-7: compression, swelling, and protection",
                    weekStart: 1,
                    weekEnd: 1,
                    summary: "Compression, fluid shifts, and bruising dominate the early stage."
                ),
                PhaseDefinition(
                    id: "body-early-contour",
                    title: "Weeks 2-6: contour changes begin slowly",
                    weekStart: 2,
                    weekEnd: 6,
                    summary: "Users often overread early swelling changes here, so the plan should emphasize patience and consistent logging."
                ),
                PhaseDefinition(
                    id: "body-mid-contour",
                    title: "Weeks 7-12: clearer contour trends",
                    weekStart: 7,
                    weekEnd: 12,
                    summary: "This phase is better for tracking how the silhouette is changing across photos and symptoms."
                ),
                PhaseDefinition(
                    id: "body-long-tail",
                    title: "Months 3-6: refinement and long-term shape",
                    weekStart: 13,
                    weekEnd: 26,
                    summary: "The roadmap should focus on contour refinement, consistency, and follow-up milestone review."
                )
            ]

        case .facialSurgery:
            return [
                PhaseDefinition(
                    id: "facial-acute",
                    title: "Days 1-10: swelling, bruising, and social downtime",
                    weekStart: 1,
                    weekEnd: 1,
                    summary: "This period is often the most emotionally intense, so reassurance and practical expectations matter most."
                ),
                PhaseDefinition(
                    id: "facial-early-settle",
                    title: "Weeks 2-4: bruising fades, tightness remains",
                    weekStart: 2,
                    weekEnd: 4,
                    summary: "The user may look more presentable while still feeling tight, numb, or uneven."
                ),
                PhaseDefinition(
                    id: "facial-mid-settle",
                    title: "Weeks 5-8: more natural movement and clearer recovery patterns",
                    weekStart: 5,
                    weekEnd: 8,
                    summary: "This is a better phase for comparing progress week by week rather than day by day."
                ),
                PhaseDefinition(
                    id: "facial-refinement",
                    title: "Months 2-4: refinement and confidence rebuilding",
                    weekStart: 9,
                    weekEnd: 16,
                    summary: "The plan should shift toward refinement, confidence, and questions about persistent irregularities."
                )
            ]

        case .other:
            return [
                PhaseDefinition(
                    id: "other-acute",
                    title: "Week 1: initial protection and stabilization",
                    weekStart: 1,
                    weekEnd: 1,
                    summary: "The first phase should focus on basic recovery protection and consistent tracking."
                ),
                PhaseDefinition(
                    id: "other-early",
                    title: "Weeks 2-4: early recovery pattern detection",
                    weekStart: 2,
                    weekEnd: 4,
                    summary: "This stage is best for identifying recovery patterns and adjusting logging prompts."
                ),
                PhaseDefinition(
                    id: "other-mid",
                    title: "Weeks 5-8: trend comparison and milestone review",
                    weekStart: 5,
                    weekEnd: 8,
                    summary: "The roadmap should focus on trend comparison and the next useful provider questions."
                ),
                PhaseDefinition(
                    id: "other-late",
                    title: "Week 9+: refinement and follow-up planning",
                    weekStart: 9,
                    weekEnd: 52,
                    summary: "Longer-term guidance should focus on progress interpretation and follow-up planning."
                )
            ]
        }
    }
}

private struct PhaseDefinition {
    let id: String
    let title: String
    let weekStart: Int
    let weekEnd: Int
    let summary: String
}
