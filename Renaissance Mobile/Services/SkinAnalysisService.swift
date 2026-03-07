//
//  SkinAnalysisService.swift
//  Renaissance Mobile
//
//  Calls the Supabase Edge Function `analyze-photo` which proxies
//  Gemini 2.5 Flash vision for post-procedure recovery analysis.
//

import Foundation
import Supabase

private let _defaultSupabase: SupabaseClient = supabase

// MARK: - Response Models

struct SkinAnalysisResult: Decodable {
    let swellingIndex: Double
    let bruisingIndex: Double
    let rednessIndex: Double
    let overallScore: Double
    let summary: String
    let zones: [SkinZoneResult]

    enum CodingKeys: String, CodingKey {
        case summary, zones
        case swellingIndex = "swellingIndex"
        case bruisingIndex = "bruisingIndex"
        case rednessIndex  = "rednessIndex"
        case overallScore  = "overallScore"
    }
}

struct SkinZoneResult: Decodable {
    let zone: String
    let score: Double
    let notes: String?
}

// MARK: - Request Model

private struct AnalysisRequest: Encodable {
    let photoUrl: String
    let procedureName: String
    let dayNumber: Int
}

// MARK: - Service

class SkinAnalysisService {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient = _defaultSupabase) {
        self.supabase = supabase
    }

    /// Sends the photo URL to the Edge Function and returns structured analysis.
    func analyze(
        photoUrl: String,
        procedureName: String,
        dayNumber: Int
    ) async throws -> SkinAnalysisResult {
        let payload = AnalysisRequest(
            photoUrl: photoUrl,
            procedureName: procedureName,
            dayNumber: dayNumber
        )

        let result: SkinAnalysisResult = try await supabase.functions
            .invoke(
                "analyze-photo",
                options: FunctionInvokeOptions(body: payload)
            )

        return result
    }
}
