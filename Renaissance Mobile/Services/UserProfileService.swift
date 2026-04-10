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
    private let transientProfileRetryDelayNs: UInt64 = 400_000_000

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - Profile Management

    /// Get the current user's profile
    func getUserProfile() async throws -> UserProfile {
        let response = try await fetchStoredUserProfile()
        return try await hydrateProfileImageURL(for: response)
    }

    private func fetchStoredUserProfile() async throws -> UserProfile {
        guard let userId = supabase.auth.currentUser?.id else {
            throw UserProfileError.notAuthenticated
        }

        let profiles: [UserProfile] = try await retryProfileFetchIfNeeded {
            try await supabase.database
                .from("user_profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .execute()
                .value
        }

        if let profile = profiles.first {
            return profile
        }

        print("Profile not found, creating new profile...")
        return try await createUserProfile()
    }

    /// Create a new user profile (typically called after sign up)
    func createUserProfile(email: String? = nil) async throws -> UserProfile {
        guard let userId = supabase.auth.currentUser?.id else {
            throw UserProfileError.notAuthenticated
        }

        let userEmail = email ?? supabase.auth.currentUser?.email

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

        return try await hydrateProfileImageURL(for: response)
    }

    /// Update user profile with all displayable fields
    func updateUserProfile(
        fullName: String? = nil,
        email: String? = nil,
        phoneNumber: String? = nil,
        zipCode: String? = nil,
        billingPlan: BillingPlan? = nil,
        profileImageData: Data? = nil,
        gender: String? = nil,
        ageRange: String? = nil,
        raceEthnicity: String? = nil,
        aestheticGoals: [String]? = nil,
        proceduresOfInterest: [String]? = nil,
        previousProcedures: [String]? = nil,
        healthFlags: [String]? = nil,
        bodyAreasOfInterest: [String]? = nil
    ) async throws -> UserProfile {
        guard let userId = supabase.auth.currentUser?.id else {
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
            profileImageUrl: profileImageUrl ?? storedProfileImageReference(from: currentProfile.profileImageUrl),
            subscriptionStatus: currentProfile.subscriptionStatus,
            subscriptionCurrentPeriodEnd: currentProfile.subscriptionCurrentPeriodEnd,
            subscriptionProvider: currentProfile.subscriptionProvider,
            subscriptionId: currentProfile.subscriptionId,
            appStoreProductId: currentProfile.appStoreProductId,
            appStoreOriginalTransactionId: currentProfile.appStoreOriginalTransactionId,
            appStoreEnvironment: currentProfile.appStoreEnvironment,
            createdAt: currentProfile.createdAt,
            updatedAt: Date(),
            metadata: currentProfile.metadata,
            gender: gender ?? currentProfile.gender,
            ageRange: ageRange ?? currentProfile.ageRange,
            raceEthnicity: raceEthnicity ?? currentProfile.raceEthnicity,
            aestheticGoals: aestheticGoals ?? currentProfile.aestheticGoals,
            proceduresOfInterest: proceduresOfInterest ?? currentProfile.proceduresOfInterest,
            previousProcedures: previousProcedures ?? currentProfile.previousProcedures,
            healthFlags: healthFlags ?? currentProfile.healthFlags,
            bodyAreasOfInterest: bodyAreasOfInterest ?? currentProfile.bodyAreasOfInterest
        )

        // Update the profile in the database
        do {
            print("💾 Updating user profile in database for user: \(userId.uuidString)")
            let response: UserProfile = try await supabase.database
                .from("user_profiles")
                .update(updatedProfile)
                .eq("id", value: userId.uuidString)
                .select()
                .single()
                .execute()
                .value

            print("✅ Successfully updated user profile")
            return try await hydrateProfileImageURL(for: response)
        } catch {
            // If update fails, the profile might not exist, so create it
            print("❌ Database update error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            print("⚠️ Update failed, attempting to create profile instead")

            // Get email from cached user if not provided
            let userEmail = email ?? supabase.auth.currentUser?.email

            let newProfile = UserProfile(
                id: userId,
                fullName: fullName,
                email: userEmail,
                phoneNumber: phoneNumber,
                zipCode: zipCode,
                billingPlan: billingPlan ?? .free,
                profileImageUrl: profileImageUrl ?? storedProfileImageReference(from: currentProfile.profileImageUrl),
                subscriptionStatus: currentProfile.subscriptionStatus,
                subscriptionCurrentPeriodEnd: currentProfile.subscriptionCurrentPeriodEnd,
                subscriptionProvider: currentProfile.subscriptionProvider,
                subscriptionId: currentProfile.subscriptionId,
                appStoreProductId: currentProfile.appStoreProductId,
                appStoreOriginalTransactionId: currentProfile.appStoreOriginalTransactionId,
                appStoreEnvironment: currentProfile.appStoreEnvironment,
                gender: gender,
                ageRange: ageRange,
                raceEthnicity: raceEthnicity,
                aestheticGoals: aestheticGoals,
                proceduresOfInterest: proceduresOfInterest,
                previousProcedures: previousProcedures,
                healthFlags: healthFlags,
                bodyAreasOfInterest: bodyAreasOfInterest
            )

            let response: UserProfile = try await supabase.database
                .from("user_profiles")
                .insert(newProfile)
                .select()
                .single()
                .execute()
                .value

            return try await hydrateProfileImageURL(for: response)
        }
    }

    /// Update user profile with a complete UserProfile object
    func updateUserProfile(_ profile: UserProfile) async throws -> UserProfile {
        guard let userId = supabase.auth.currentUser?.id else {
            throw UserProfileError.notAuthenticated
        }

        // Verify the profile belongs to the current user
        guard profile.id == userId else {
            throw UserProfileError.unauthorized
        }

        let storedProfile = UserProfile(
            id: profile.id,
            fullName: profile.fullName,
            email: profile.email,
            phoneNumber: profile.phoneNumber,
            zipCode: profile.zipCode,
            billingPlan: profile.billingPlan,
            profileImageUrl: storedProfileImageReference(from: profile.profileImageUrl),
            subscriptionStatus: profile.subscriptionStatus,
            subscriptionCurrentPeriodEnd: profile.subscriptionCurrentPeriodEnd,
            subscriptionProvider: profile.subscriptionProvider,
            subscriptionId: profile.subscriptionId,
            appStoreProductId: profile.appStoreProductId,
            appStoreOriginalTransactionId: profile.appStoreOriginalTransactionId,
            appStoreEnvironment: profile.appStoreEnvironment,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt,
            metadata: profile.metadata,
            gender: profile.gender,
            ageRange: profile.ageRange,
            raceEthnicity: profile.raceEthnicity,
            aestheticGoals: profile.aestheticGoals,
            proceduresOfInterest: profile.proceduresOfInterest,
            previousProcedures: profile.previousProcedures,
            healthFlags: profile.healthFlags,
            bodyAreasOfInterest: profile.bodyAreasOfInterest
        )

        let response: UserProfile = try await supabase.database
            .from("user_profiles")
            .update(storedProfile)
            .eq("id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value

        return try await hydrateProfileImageURL(for: response)
    }

    /// Merge metadata keys into the current profile metadata payload.
    func updateMetadata(_ updates: [String: AnyCodable]) async throws -> UserProfile {
        var profile = try await getUserProfile()
        var mergedMetadata = profile.metadata ?? [:]

        for (key, value) in updates {
            mergedMetadata[key] = value
        }

        profile.metadata = mergedMetadata
        profile.updatedAt = Date()
        return try await updateUserProfile(profile)
    }

    // MARK: - Profile Image Management

    /// Upload profile image to Supabase Storage and return the storage path.
    func uploadProfileImage(_ imageData: Data, userId: UUID) async throws -> String {
        // Determine file extension from image data
        let fileExtension = getImageExtension(from: imageData)

        // Create file path: {user_id}/profile.{ext}
        // IMPORTANT: Use lowercased UUID to match auth.uid() in PostgreSQL policies
        let filePath = "\(userId.uuidString.lowercased())/profile.\(fileExtension)"

        // Check if file already exists and delete it
        do {
            try await supabase.storage
                .from("profile-image")
                .remove(paths: [filePath])
        } catch {
            // Ignore error if file doesn't exist.
        }

        // Upload to storage bucket
        do {
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
        } catch {
            throw UserProfileError.uploadFailed
        }

        // Clear old cached image for this user (if any exists)
        // This ensures the new image is fetched on next load
        ImageCache.shared.clearCache()

        return filePath
    }

    /// Delete profile image from Supabase Storage
    func deleteProfileImage() async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw UserProfileError.notAuthenticated
        }

        // Get current profile to find image URL
        let profile = try await getUserProfile()

        guard let imageUrl = profile.profileImageUrl else {
            return // No image to delete
        }

        guard let path = storedProfileImageReference(from: imageUrl) else {
            throw UserProfileError.invalidImageUrl
        }

        try await supabase.storage
            .from("profile-image")
            .remove(paths: [path])

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
            subscriptionStatus: currentProfile.subscriptionStatus,
            subscriptionCurrentPeriodEnd: currentProfile.subscriptionCurrentPeriodEnd,
            subscriptionProvider: currentProfile.subscriptionProvider,
            subscriptionId: currentProfile.subscriptionId,
            appStoreProductId: currentProfile.appStoreProductId,
            appStoreOriginalTransactionId: currentProfile.appStoreOriginalTransactionId,
            appStoreEnvironment: currentProfile.appStoreEnvironment,
            createdAt: currentProfile.createdAt,
            updatedAt: Date(),
            metadata: currentProfile.metadata,
            gender: currentProfile.gender,
            ageRange: currentProfile.ageRange,
            raceEthnicity: currentProfile.raceEthnicity,
            aestheticGoals: currentProfile.aestheticGoals,
            proceduresOfInterest: currentProfile.proceduresOfInterest,
            previousProcedures: currentProfile.previousProcedures,
            healthFlags: currentProfile.healthFlags,
            bodyAreasOfInterest: currentProfile.bodyAreasOfInterest
        )

        _ = try await supabase.database
            .from("user_profiles")
            .update(updatedProfile)
            .eq("id", value: userId.uuidString)
            .execute()
    }

    private func hydrateProfileImageURL(for profile: UserProfile) async throws -> UserProfile {
        guard let storedReference = storedProfileImageReference(from: profile.profileImageUrl) else {
            return profile
        }

        let signedURL = try await supabase.storage
            .from("profile-image")
            .createSignedURL(path: storedReference, expiresIn: 3_600)

        var hydrated = profile
        hydrated.profileImageUrl = signedURL.absoluteString
        return hydrated
    }

    private func storedProfileImageReference(from storedValue: String?) -> String? {
        guard let storedValue, !storedValue.isEmpty else { return nil }

        if !storedValue.contains("://") {
            return storedValue
        }

        guard let url = URL(string: storedValue) else { return nil }
        let components = url.pathComponents

        if let bucketIndex = components.firstIndex(of: "profile-image"), bucketIndex + 1 < components.count {
            return components[(bucketIndex + 1)...].joined(separator: "/")
        }

        return nil
    }

    private func retryProfileFetchIfNeeded<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            guard shouldRetryProfileFetch(for: error) else {
                throw error
            }

            try? await Task.sleep(nanoseconds: transientProfileRetryDelayNs)
            return try await operation()
        }
    }

    private func shouldRetryProfileFetch(for error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost, .timedOut, .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost:
                return true
            default:
                return false
            }
        }

        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }

        switch nsError.code {
        case URLError.networkConnectionLost.rawValue,
             URLError.timedOut.rawValue,
             URLError.notConnectedToInternet.rawValue,
             URLError.cannotConnectToHost.rawValue,
             URLError.cannotFindHost.rawValue:
            return true
        default:
            return false
        }
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
