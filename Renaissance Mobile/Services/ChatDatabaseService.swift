//
//  ChatDatabaseService.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/10/25.
//

import Foundation
import Supabase

/// Service for managing chat conversations and messages in Supabase
class ChatDatabaseService {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - Conversations

    /// Create a new conversation for the current user
    func createConversation(title: String? = nil) async throws -> ChatConversation {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw ChatDatabaseError.notAuthenticated
        }

        let conversation = ChatConversation(
            userId: userId,
            title: title
        )

        let response: ChatConversation = try await supabase.database
            .from("chat_conversations")
            .insert(conversation)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    /// Get all conversations for the current user
    func getConversations(includeArchived: Bool = false) async throws -> [ChatConversation] {
        var query = supabase.database
            .from("chat_conversations")
            .select()

        if !includeArchived {
            query = query.eq("is_archived", value: false)
        }

        let response: [ChatConversation] = try await query
            .order("updated_at", ascending: false)
            .execute()
            .value

        return response
    }

    /// Get a specific conversation by ID
    func getConversation(id: UUID) async throws -> ChatConversation? {
        let response: ChatConversation? = try? await supabase.database
            .from("chat_conversations")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value

        return response
    }

    /// Update conversation (title, metadata, etc.)
    func updateConversation(_ conversation: ChatConversation) async throws {
        try await supabase.database
            .from("chat_conversations")
            .update(conversation)
            .eq("id", value: conversation.id.uuidString)
            .execute()
    }

    /// Archive a conversation (soft delete)
    func archiveConversation(id: UUID) async throws {
        try await supabase.database
            .from("chat_conversations")
            .update(["is_archived": true])
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Delete a conversation permanently
    func deleteConversation(id: UUID) async throws {
        try await supabase.database
            .from("chat_conversations")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Messages

    /// Get all messages for a conversation
    func getMessages(conversationId: UUID) async throws -> [ChatMessage] {
        let response: [ChatMessage] = try await supabase.database
            .from("chat_messages")
            .select()
            .eq("conversation_id", value: conversationId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        return response
    }

    /// Get messages with pagination
    func getMessages(conversationId: UUID, limit: Int = 50, offset: Int = 0) async throws -> [ChatMessage] {
        let response: [ChatMessage] = try await supabase.database
            .from("chat_messages")
            .select()
            .eq("conversation_id", value: conversationId.uuidString)
            .order("created_at", ascending: true)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return response
    }

    /// Save a new message to the database
    func saveMessage(_ message: ChatMessage) async throws -> ChatMessage {
        let response: ChatMessage = try await supabase.database
            .from("chat_messages")
            .insert(message)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    /// Update an existing message
    func updateMessage(_ message: ChatMessage) async throws {
        try await supabase.database
            .from("chat_messages")
            .update(message)
            .eq("id", value: message.id.uuidString)
            .execute()
    }

    /// Delete a message
    func deleteMessage(id: UUID) async throws {
        try await supabase.database
            .from("chat_messages")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Image Upload

    /// Upload image to Supabase Storage and return URL
    func uploadImage(_ imageData: Data, conversationId: UUID, messageId: UUID) async throws -> String {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw ChatDatabaseError.notAuthenticated
        }

        // Determine file extension from image data
        let fileExtension = getImageExtension(from: imageData)

        // Create file path: {user_id}/{conversation_id}/{message_id}.{ext}
        let filePath = "\(userId.uuidString)/\(conversationId.uuidString)/\(messageId.uuidString).\(fileExtension)"

        // Upload to storage bucket
        try await supabase.storage
            .from("chat-images")
            .upload(
                path: filePath,
                file: imageData,
                options: FileOptions(
                    contentType: "image/\(fileExtension)"
                )
            )

        // Get public URL
        let publicURL = try supabase.storage
            .from("chat-images")
            .getPublicURL(path: filePath)

        return publicURL.absoluteString
    }

    /// Delete image from Supabase Storage
    func deleteImage(imageUrl: String) async throws {
        // Extract file path from URL
        guard let url = URL(string: imageUrl),
              let pathComponents = url.pathComponents.dropFirst(3).joined(separator: "/") as String? else {
            throw ChatDatabaseError.invalidImageUrl
        }

        try await supabase.storage
            .from("chat-images")
            .remove(paths: [pathComponents])
    }

    // MARK: - Helper Methods

    private func getImageExtension(from imageData: Data) -> String {
        guard imageData.count > 12 else { return "jpg" }

        // Check PNG signature
        if imageData[0] == 0x89 && imageData[1] == 0x50 && imageData[2] == 0x4E && imageData[3] == 0x47 {
            return "png"
        }

        // Check JPEG signature
        if imageData[0] == 0xFF && imageData[1] == 0xD8 && imageData[2] == 0xFF {
            return "jpg"
        }

        // Check GIF signature
        if imageData[0] == 0x47 && imageData[1] == 0x49 && imageData[2] == 0x46 {
            return "gif"
        }

        // Check WebP signature
        if imageData[8] == 0x57 && imageData[9] == 0x45 && imageData[10] == 0x42 && imageData[11] == 0x50 {
            return "webp"
        }

        // Default to jpg
        return "jpg"
    }
}

// MARK: - Errors

enum ChatDatabaseError: LocalizedError {
    case notAuthenticated
    case invalidImageUrl
    case conversationNotFound
    case messageNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidImageUrl:
            return "Invalid image URL format"
        case .conversationNotFound:
            return "Conversation not found"
        case .messageNotFound:
            return "Message not found"
        }
    }
}
