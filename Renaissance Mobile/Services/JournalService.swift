//
//  JournalService.swift
//  Renaissance Mobile
//
//  Uses URLSession directly against the Supabase REST API to avoid the
//  Supabase Swift SDK's internal swift-dependencies machinery, which triggers
//  a CODESIGNING fault on iOS 26 beta when first accessed from a concurrent
//  thread (type metadata for Dependencies lives in dyld __DATA_DIRTY).
//

import Foundation
import Supabase

class JournalService {

    // MARK: - Shared URL / auth helpers

    private var base: String { AppConfig.supabaseURL + "/rest/v1" }
    private var storageBase: String { AppConfig.supabaseURL + "/storage/v1" }
    private var key: String { AppConfig.supabaseAnonKey }

    private var token: String {
        supabase.auth.currentSession?.accessToken ?? key
    }

    private var commonHeaders: [String: String] {
        [
            "apikey": key,
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json",
            "Accept": "application/json",
        ]
    }

    // MARK: - Decoder / Encoder

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = withFrac.date(from: s) { return date }
            if let date = plain.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unrecognised date: \(s)")
        }
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - Request builder

    private func makeRequest(
        _ path: String,
        method: String,
        query: [String: String] = [:],
        body: Data? = nil,
        prefer: String? = nil,
        accept: String? = nil
    ) throws -> URLRequest {
        var components = URLComponents(string: path)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        commonHeaders.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let accept { req.setValue(accept, forHTTPHeaderField: "Accept") }
        req.httpBody = body
        return req
    }

    private func execute(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? "(empty)"
            throw JournalError.serverError(http.statusCode, body)
        }
        return data
    }

    // MARK: - Fetch

    func fetchEntries(for procedureId: String? = nil) async throws -> [JournalEntry] {
        guard let userId = supabase.auth.currentUser?.id else {
            throw JournalError.notAuthenticated
        }
        var query: [String: String] = [
            "user_id": "eq.\(userId.uuidString)",
            "order": "entry_date.desc",
        ]
        if let procedureId { query["procedure_id"] = "eq.\(procedureId)" }
        let req = try makeRequest(base + "/journal_entries", method: "GET", query: query)
        let data = try await execute(req)
        return try Self.decoder.decode([JournalEntry].self, from: data)
    }

    func fetchEntry(id: UUID) async throws -> JournalEntry {
        guard let userId = supabase.auth.currentUser?.id else {
            throw JournalError.notAuthenticated
        }
        let req = try makeRequest(
            base + "/journal_entries", method: "GET",
            query: ["id": "eq.\(id.uuidString)", "user_id": "eq.\(userId.uuidString)"],
            accept: "application/vnd.pgrst.object+json"
        )
        let data = try await execute(req)
        return try Self.decoder.decode(JournalEntry.self, from: data)
    }

    // MARK: - Create

    func createEntry(
        procedureId: String,
        procedureName: String,
        dayNumber: Int,
        entryDate: Date = Date(),
        notes: String?,
        photoData: Data?,
        painLevel: Int? = nil,
        bruisingLevel: Int? = nil,
        swellingLevel: Int? = nil,
        rednessLevel: Int? = nil
    ) async throws -> JournalEntry {
        guard let userId = supabase.auth.currentUser?.id else {
            throw JournalError.notAuthenticated
        }

        let entryId = UUID()
        var photoPath: String?
        var photoUrl: String?

        if let data = photoData {
            (photoPath, photoUrl) = try await uploadPhoto(data, entryId: entryId, userId: userId)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let payload = JournalEntryInsert(
            userId: userId,
            procedureId: procedureId,
            procedureName: procedureName,
            dayNumber: dayNumber,
            entryDate: formatter.string(from: entryDate),
            notes: notes,
            photoPath: photoPath,
            photoUrl: photoUrl,
            painLevel: painLevel,
            bruisingLevel: bruisingLevel,
            swellingLevel: swellingLevel,
            rednessLevel: rednessLevel
        )

        let body = try Self.encoder.encode(payload)
        let req = try makeRequest(
            base + "/journal_entries", method: "POST",
            body: body,
            prefer: "return=representation",
            accept: "application/vnd.pgrst.object+json"
        )
        let data = try await execute(req)
        return try Self.decoder.decode(JournalEntry.self, from: data)
    }

    // MARK: - Update

    func updateNotes(id: UUID, notes: String) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw JournalError.notAuthenticated
        }
        struct Patch: Encodable { let notes: String }
        let body = try Self.encoder.encode(Patch(notes: notes))
        let req = try makeRequest(
            base + "/journal_entries", method: "PATCH",
            query: ["id": "eq.\(id.uuidString)", "user_id": "eq.\(userId.uuidString)"],
            body: body
        )
        _ = try await execute(req)
    }

    // MARK: - Delete

    func deleteEntry(id: UUID) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw JournalError.notAuthenticated
        }
        if let entry = try? await fetchEntry(id: id), let path = entry.photoPath {
            try? await deletePhoto(path: path)
        }
        let req = try makeRequest(
            base + "/journal_entries", method: "DELETE",
            query: ["id": "eq.\(id.uuidString)", "user_id": "eq.\(userId.uuidString)"]
        )
        _ = try await execute(req)
    }

    // MARK: - Photo Upload

    func uploadPhoto(_ data: Data, entryId: UUID, userId: UUID) async throws -> (String, String) {
        let ext = imageExtension(from: data)
        let path = "\(userId.uuidString.lowercased())/\(entryId.uuidString).\(ext)"

        // Upload binary — both URLRequest.httpBody setter and URLSession.upload(for:from:) async
        // crash on iOS 26 beta (broken CheckedContinuation / NSMutableURLRequest bridge).
        // Use the callback-based uploadTask wrapped in a continuation instead.
        var uploadReq = URLRequest(url: URL(string: "\(storageBase)/object/journals/\(path)")!)
        uploadReq.httpMethod = "POST"
        uploadReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        uploadReq.setValue(key, forHTTPHeaderField: "apikey")
        uploadReq.setValue("image/\(ext)", forHTTPHeaderField: "Content-Type")
        uploadReq.setValue("true", forHTTPHeaderField: "x-upsert")
        let uploadResponse: URLResponse = try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.uploadTask(with: uploadReq, from: data) { _, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let response {
                    continuation.resume(returning: response)
                } else {
                    continuation.resume(throwing: JournalError.uploadFailed)
                }
            }.resume()
        }
        if let http = uploadResponse as? HTTPURLResponse, http.statusCode >= 400 {
            throw JournalError.uploadFailed
        }

        // Request signed URL (1 year)
        var signReq = URLRequest(url: URL(string: "\(storageBase)/object/sign/journals/\(path)")!)
        signReq.httpMethod = "POST"
        signReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        signReq.setValue(key, forHTTPHeaderField: "apikey")
        signReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        signReq.httpBody = try JSONEncoder().encode(["expiresIn": 31_536_000])
        let signData = try await execute(signReq)

        struct SignResponse: Decodable { let signedURL: String }
        let signedPath = try JSONDecoder().decode(SignResponse.self, from: signData).signedURL
        let fullURL = AppConfig.supabaseURL + "/storage/v1" + signedPath

        return (path, fullURL)
    }

    private func deletePhoto(path: String) async throws {
        var req = URLRequest(url: URL(string: "\(storageBase)/object/journals/\(path)")!)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(key, forHTTPHeaderField: "apikey")
        _ = try await execute(req)
    }

    // MARK: - Helpers

    private func imageExtension(from data: Data) -> String {
        guard data.count > 12 else { return "jpg" }
        if data[0] == 0x89 && data[1] == 0x50 { return "png" }
        if data[0] == 0xFF && data[1] == 0xD8 { return "jpg" }
        if data[8] == 0x57 && data[9] == 0x45 { return "webp" }
        return "jpg"
    }
}

extension JournalService: JournalServiceProtocol {}

// MARK: - Errors

enum JournalError: LocalizedError {
    case notAuthenticated
    case entryNotFound
    case uploadFailed
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:        return "User is not authenticated"
        case .entryNotFound:           return "Journal entry not found"
        case .uploadFailed:            return "Failed to upload photo"
        case .serverError(let code, let body): return "Server error \(code): \(body)"
        }
    }
}
