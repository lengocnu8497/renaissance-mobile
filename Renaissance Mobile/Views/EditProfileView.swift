//
//  EditProfileView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    // Profile data
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var zipCode: String = ""
    @State private var profileImageUrl: String?

    // Image picker
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var profileImage: UIImage?

    // State management
    @State private var isLoading: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false

    // Service
    private let profileService = UserProfileService(supabase: supabase)

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundProfile
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: Theme.Spacing.xl) {
                                // Avatar Section
                                avatarSection
                                    .padding(.top, Theme.Spacing.xl)

                            // Form Fields
                            VStack(spacing: Theme.Spacing.lg) {
                            // Full Name
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text("Full Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Theme.Colors.textProfilePrimary)

                                TextField("", text: $fullName)
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.textProfilePrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                            .stroke(Theme.Colors.borderLight, lineWidth: 1)
                                    )
                                    .cornerRadius(Theme.CornerRadius.medium)
                            }

                            // Email
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text("Email")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Theme.Colors.textProfilePrimary)

                                TextField("", text: $email)
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.textProfilePrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                            .stroke(Theme.Colors.borderLight, lineWidth: 1)
                                    )
                                    .cornerRadius(Theme.CornerRadius.medium)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                            }

                            // Phone Number
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text("Phone Number")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Theme.Colors.textProfilePrimary)

                                TextField("", text: $phoneNumber)
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.textProfilePrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                            .stroke(Theme.Colors.borderLight, lineWidth: 1)
                                    )
                                    .cornerRadius(Theme.CornerRadius.medium)
                                    .keyboardType(.phonePad)
                            }

                            // Zip Code
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text("Zip Code")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Theme.Colors.textProfilePrimary)

                                TextField("", text: $zipCode)
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.textProfilePrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                            .stroke(Theme.Colors.borderLight, lineWidth: 1)
                                    )
                                    .cornerRadius(Theme.CornerRadius.medium)
                                    .keyboardType(.numberPad)
                            }
                            }
                            .padding(.horizontal, Theme.Spacing.xl)

                            Spacer(minLength: 100)
                        }
                    }

                    // Save Button
                    saveButton
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.lg)
                        .background(Theme.Colors.backgroundProfile)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.Colors.textProfilePrimary)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .task {
                await loadProfile()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                        profileImage = UIImage(data: data)
                    }
                }
            }
        }
    }

    // MARK: - Avatar Section
    private var avatarSection: some View {
        ZStack(alignment: .bottomTrailing) {
            // Avatar Circle
            Circle()
                .fill(Theme.Colors.primaryProfile.opacity(0.3))
                .frame(width: Theme.IconSize.profileAvatar, height: Theme.IconSize.profileAvatar)
                .overlay(
                    Group {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: Theme.IconSize.profileAvatar, height: Theme.IconSize.profileAvatar)
                                .clipShape(Circle())
                        } else if let imageUrl = profileImageUrl, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: Theme.IconSize.profileAvatar, height: Theme.IconSize.profileAvatar)
                                    .clipShape(Circle())
                            } placeholder: {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(Theme.Colors.textProfilePrimary.opacity(0.6))
                            }
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Theme.Colors.textProfilePrimary.opacity(0.6))
                        }
                    }
                )

            // Edit Button with PhotosPicker
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Circle()
                    .fill(Theme.Colors.primaryProfile)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .offset(x: 4, y: 4)
        }
    }

    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: {
            Task {
                await saveProfile()
            }
        }) {
            if isSaving {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(Theme.CornerRadius.medium)
            } else {
                Text("Save Changes")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(Theme.CornerRadius.medium)
            }
        }
        .disabled(isSaving)
    }

    // MARK: - Data Methods

    /// Load user profile from Supabase
    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await profileService.getUserProfile()
            await MainActor.run {
                fullName = profile.fullName ?? ""
                email = profile.email ?? ""
                phoneNumber = profile.phoneNumber ?? ""
                zipCode = profile.zipCode ?? ""
                profileImageUrl = profile.profileImageUrl
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load profile: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    /// Save profile changes to Supabase
    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }

        do {
            // Convert UIImage to Data if needed
            var imageData: Data?
            if let selectedData = selectedImageData {
                imageData = selectedData
            }

            // Update profile with all fields
            _ = try await profileService.updateUserProfile(
                fullName: fullName.isEmpty ? nil : fullName,
                email: email.isEmpty ? nil : email,
                phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                zipCode: zipCode.isEmpty ? nil : zipCode,
                billingPlan: nil, // Keep existing billing plan
                profileImageData: imageData
            )

            // Dismiss on success
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save profile: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

#Preview {
    EditProfileView()
}
