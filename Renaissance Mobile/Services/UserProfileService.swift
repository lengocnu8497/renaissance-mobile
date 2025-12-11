//
//  UserProfileService.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/10/25.
//

import Foundation
import Supabase

/// Service for managing user profiles in Supabase
class UserProfileService {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - Profile Management

    /// Get the current user's profile
    func getUserProfile() async throws -> UserProfile {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw UserProfileError.notAuthenticated
        }

        do {
            let response: UserProfile = try await supabase.database
                .from("user_profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value

            return response
        } catch {
            // If profile doesn't exist, create it
            print("Profile not found, creating new profile...")
            return try await createUserProfile()
        }
    }

    /// Create a new user profile (typically called after sign up)
    func createUserProfile(email: String? = nil) async throws -> UserProfile {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw UserProfileError.notAuthenticated
        }

        let session = try await supabase.auth.session
        let userEmail = email ?? session.user.email

        let profile = UserProfile(
            id: userId,
            email: userEmail
        )

        let response: UserProfile = try await supabase.database
            .from("user_profiles")
            .insert(profile)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    /// Update user profile with all displayable fields
    func updateUserProfile(
        fullName: String? = nil,
        email: String? = nil,
        phoneNumber: String? = nil,
        zipCode: String? = nil,
        billingPlan: BillingPlan? = nil,
        profileImageData: Data? = nil
    ) async throws -> UserProfile {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw UserProfileError.notAuthenticated
        }

        // Upload profile image if provided
        var profileImageUrl: String?
        if let imageData = profileImageData {
            profileImageUrl = try await uploadProfileImage(imageData, userId: userId)
        }

        // Get current profile to preserve fields not being updated
        let currentProfile = try await getUserProfile()

        // Build updated profile with new values
        let updatedProfile = UserProfile(
            id: currentProfile.id,
            fullName: fullName ?? currentProfile.fullName,
            email: email ?? currentProfile.email,
            phoneNumber: phoneNumber ?? currentProfile.phoneNumber,
            zipCode: zipCode ?? currentProfile.zipCode,
            billingPlan: billingPlan ?? currentProfile.billingPlan,
            profileImageUrl: profileImageUrl ?? currentProfile.profileImageUrl,
            createdAt: currentProfile.createdAt,
            updatedAt: Date(),
            metadata: currentProfile.metadata
        )

        // Update the profile in the database
        do {
            let response: UserProfile = try await supabase.database
                .from("user_profiles")
                .update(updatedProfile)
                .eq("id", value: userId.uuidString)
                .select()
                .single()
                .execute()
                .value

            return response
        } catch {
            // If update fails, the profile might not exist, so create it
            print("Update failed, attempting to create profile: \(error)")

            // Get email from session if not provided
            let session = try await supabase.auth.session
            let userEmail = email ?? session.user.email

            let newProfile = UserProfile(
                id: userId,
                fullName: fullName,
                email: userEmail,
                phoneNumber: phoneNumber,
                zipCode: zipCode,
                billingPlan: billingPlan ?? .free,
                profileImageUrl: profileImageUrl
            )

            let response: UserProfile = try await supabase.database
                .from("user_profiles")
                .insert(newProfile)
                .select()
                .single()
                .execute()
                .value

            return response
        }
    }

    /// Update user profile with a complete UserProfile object
    func updateUserProfile(_ profile: UserProfile) async throws -> UserProfile {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw UserProfileError.notAuthenticated
        }

        // Verify the profile belongs to the current user
        guard profile.id == userId else {
            throw UserProfileError.unauthorized
        }

        let response: UserProfile = try await supabase.database
            .from("user_profiles")
            .update(profile)
            .eq("id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    // MARK: - Profile Image Management

    /// Upload profile image to Supabase Storage and return URL
    func uploadProfileImage(_ imageData: Data, userId: UUID) async throws -> String {
        // Determine file extension from image data
        let fileExtension = getImageExtension(from: imageData)

        // Create file path: {user_id}/profile.{ext}
        let filePath = "\(userId.uuidString)/profile.\(fileExtension)"

        // Check if file already exists and delete it
        do {
            try await supabase.storage
                .from("profile-image")
                .remove(paths: [filePath])
        } catch {
            // Ignore error if file doesn't exist
            print("No existing profile image to delete")
        }

        // Upload to storage bucket
        try await supabase.storage
            .from("profile-image")
            .upload(
                path: filePath,
                file: imageData,
                options: FileOptions(
                    contentType: "image/\(fileExtension)",
                    upsert: true
                )
            )

        // Get public URL
        let publicURL = try supabase.storage
            .from("profile-image")
            .getPublicURL(path: filePath)

        return publicURL.absoluteString
    }

    /// Delete profile image from Supabase Storage
    func deleteProfileImage() async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw UserProfileError.notAuthenticated
        }

        // Get current profile to find image URL
        let profile = try await getUserProfile()

        guard let imageUrl = profile.profileImageUrl else {
            return // No image to delete
        }

        // Extract file path from URL
        guard let url = URL(string: imageUrl),
              let pathComponents = url.pathComponents.dropFirst(3).joined(separator: "/") as String? else {
            throw UserProfileError.invalidImageUrl
        }

        try await supabase.storage
            .from("profile-image")
            .remove(paths: [pathComponents])

        // Update profile to remove image URL
        let currentProfile = try await getUserProfile()
        let updatedProfile = UserProfile(
            id: currentProfile.id,
            fullName: currentProfile.fullName,
            email: currentProfile.email,
            phoneNumber: currentProfile.phoneNumber,
            zipCode: currentProfile.zipCode,
            billingPlan: currentProfile.billingPlan,
            profileImageUrl: nil,
            createdAt: currentProfile.createdAt,
            updatedAt: Date(),
            metadata: currentProfile.metadata
        )

        _ = try await supabase.database
            .from("user_profiles")
            .update(updatedProfile)
            .eq("id", value: userId.uuidString)
            .execute()
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

enum UserProfileError: LocalizedError {
    case notAuthenticated
    case unauthorized
    case profileNotFound
    case invalidImageUrl
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .unauthorized:
            return "You don't have permission to modify this profile"
        case .profileNotFound:
            return "User profile not found"
        case .invalidImageUrl:
            return "Invalid profile image URL format"
        case .uploadFailed:
            return "Failed to upload profile image"
        }
    }
}
