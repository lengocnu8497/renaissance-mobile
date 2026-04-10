//
//  ProtectedLocalStore.swift
//  Renaissance Mobile
//
//  Stores sensitive local data in Application Support with file protection
//  instead of plain UserDefaults.
//

import Foundation
import CryptoKit

enum ProtectedLocalStore {
    private static let directoryName = "ProtectedLocalStore"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func save<Value: Codable>(_ value: Value, forKey key: String) throws {
        let data = try encoder.encode(value)
        let url = try fileURL(forKey: key)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    static func load<Value: Codable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let url = try? fileURL(forKey: key),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? decoder.decode(type, from: data)
    }

    static func remove(forKey key: String) {
        guard let url = try? fileURL(forKey: key) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func removeAll(withPrefix prefix: String) {
        guard let directoryURL = try? directoryURL() else { return }
        let prefixToken = sanitizedPrefix(prefix) + "--"

        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in fileURLs where fileURL.lastPathComponent.hasPrefix(prefixToken) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    static func loadAll<Value: Codable>(_ type: Value.Type, withPrefix prefix: String) -> [Value] {
        guard let directoryURL = try? directoryURL() else { return [] }
        let prefixToken = sanitizedPrefix(prefix) + "--"

        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return fileURLs
            .filter { $0.lastPathComponent.hasPrefix(prefixToken) }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? decoder.decode(type, from: $0) }
    }

    private static func fileURL(forKey key: String) throws -> URL {
        try directoryURL().appendingPathComponent(filename(forKey: key), isDirectory: false)
    }

    private static func directoryURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent(directoryName, isDirectory: true)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )

        return directory
    }

    private static func filename(forKey key: String) -> String {
        "\(sanitizedPrefix(key))--\(sha256(key)).json"
    }

    private static func sanitizedPrefix(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(scalars)
    }

    private static func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
