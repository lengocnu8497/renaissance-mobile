//
//  ProceduresViewModel.swift
//  Renaissance Mobile
//

import Foundation
import Supabase

@MainActor
@Observable
class ProceduresViewModel {
    var procedures: [Procedure] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Filtered + Searched Results

    func filtered(by filter: String, searchText: String) -> [Procedure] {
        // When searching, go cross-category so results aren't missed
        let pool: [Procedure]
        if !searchText.isEmpty {
            pool = procedures
        } else {
            switch filter {
            case "Non-Surgical":
                pool = procedures.filter { !$0.isSurgical }
            case "Surgical":
                pool = procedures.filter { $0.isSurgical }
            default:
                pool = procedures.filter { $0.category == filter }
            }
        }

        guard !searchText.isEmpty else { return pool }
        let query = searchText.lowercased()
        return pool.filter {
            $0.name.lowercased().contains(query) ||
            $0.description.lowercased().contains(query)
        }
    }

    // MARK: - Fetch

    func fetchProcedures() async {
        guard procedures.isEmpty else { return } // already loaded
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            procedures = try await supabase.database
                .from("procedures")
                .select()
                .order("sort_order", ascending: true)
                .execute()
                .value
        } catch {
            print("❌ fetchProcedures error: \(error)")
            errorMessage = "Unable to load procedures"
        }
    }
}
