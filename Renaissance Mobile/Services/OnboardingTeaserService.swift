//
//  OnboardingTeaserService.swift
//  Renaissance Mobile
//

import Foundation
import Supabase

struct OnboardingTeaserContent: Decodable, Equatable {
    let headline: String
    let body: String
    let bullets: [String]
}

struct OnboardingTeaserRequest: Encodable {
    let branch: String
    let procedureName: String?
    let bodyAreas: [String]?
    let healthFlags: [String]?
    // Researching
    let researchStage: String?
    let researchNeeds: [String]?
    // Planning
    let consultationStatus: String?
    let planningTimeline: String?
    // Recovering
    let procedureDate: String?
    let emotionalState: String?
}

enum OnboardingTeaserError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        "Unable to generate your personalized preview right now."
    }
}

final class OnboardingTeaserService {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient = Renaissance_Mobile.supabase) {
        self.supabase = supabase
    }

    func generate(request: OnboardingTeaserRequest) async throws -> OnboardingTeaserContent {
        let response: OnboardingTeaserContent = try await supabase.functions.invoke(
            "generate-onboarding-teaser",
            options: FunctionInvokeOptions(body: request)
        )
        return response
    }
}
