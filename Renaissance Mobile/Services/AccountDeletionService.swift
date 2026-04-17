//
//  AccountDeletionService.swift
//  Renaissance Mobile
//

import Foundation
import Supabase

struct AccountDeletionResponse: Decodable {
    let success: Bool
}

enum AccountDeletionError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be signed in to delete your account."
        }
    }
}

struct AccountDeletionService {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    func deleteCurrentAccount() async throws {
        guard supabase.auth.currentUser != nil else {
            throw AccountDeletionError.notAuthenticated
        }

        let _: AccountDeletionResponse = try await supabase.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(body: EmptyDeletionRequest())
        )
    }

    private struct EmptyDeletionRequest: Encodable {}
}
