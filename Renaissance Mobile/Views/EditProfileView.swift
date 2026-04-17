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

    // AI personalization context
    @State private var gender: String? = nil
    @State private var ageRange: String? = nil
    @State private var raceEthnicity: String? = nil
    @State private var aestheticGoals: Set<String> = []
    @State private var bodyAreas: Set<String> = []
    @State private var proceduresOfInterest: Set<String> = []
    @State private var previousProcedures: Set<String> = []
    @State private var healthFlags: Set<String> = []

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

                            // MARK: Personalization Context
                            VStack(alignment: .leading, spacing: 24) {
                                profileSectionHeader("About You")
                                    .padding(.horizontal, Theme.Spacing.xl)

                                profileChipGroup(title: "Gender identity", options: ProfileSelectionCatalog.genderOptions,
                                                 selected: gender.map { [$0] } ?? [], multiSelect: false) { val in
                                    gender = gender == val ? nil : val
                                }
                                .padding(.horizontal, Theme.Spacing.xl)

                                profileChipGroup(title: "Age range", options: ProfileSelectionCatalog.ageRangeOptions,
                                                 selected: ageRange.map { [$0] } ?? [], multiSelect: false) { val in
                                    ageRange = ageRange == val ? nil : val
                                }
                                .padding(.horizontal, Theme.Spacing.xl)

                                profileChipGroup(title: "Race / Ethnicity", options: ProfileSelectionCatalog.raceOptions,
                                                 selected: raceEthnicity.map { [$0] } ?? [], multiSelect: false) { val in
                                    raceEthnicity = raceEthnicity == val ? nil : val
                                }
                                .padding(.horizontal, Theme.Spacing.xl)

                                profileSectionHeader("Aesthetic Goals")
                                    .padding(.horizontal, Theme.Spacing.xl)

                                profileChipGroup(title: "What I'm hoping to achieve",
                                                 options: ProfileSelectionCatalog.goalOptions, selected: Array(aestheticGoals),
                                                 multiSelect: true) { val in
                                    if aestheticGoals.contains(val) { aestheticGoals.remove(val) } else { aestheticGoals.insert(val) }
                                }
                                .padding(.horizontal, Theme.Spacing.xl)

                                profileChipGroup(title: "Body areas of interest",
                                                 options: ProfileSelectionCatalog.bodyAreaOptions, selected: Array(bodyAreas),
                                                 multiSelect: true) { val in
                                    if bodyAreas.contains(val) { bodyAreas.remove(val) } else { bodyAreas.insert(val) }
                                }
                                .padding(.horizontal, Theme.Spacing.xl)

                                profileChipGroup(title: "Procedures I'm considering",
                                                 options: ProfileSelectionCatalog.procedureOptions, selected: Array(proceduresOfInterest),
                                                 multiSelect: true) { val in
                                    if proceduresOfInterest.contains(val) { proceduresOfInterest.remove(val) } else { proceduresOfInterest.insert(val) }
                                }
                                .padding(.horizontal, Theme.Spacing.xl)

                                profileSectionHeader("Health & History")
                                    .padding(.horizontal, Theme.Spacing.xl)

                                profileChipGroup(title: "Procedures I've already had",
                                                 options: ProfileSelectionCatalog.previousProcedureOptions, selected: Array(previousProcedures),
                                                 multiSelect: true) { val in
                                    if previousProcedures.contains(val) { previousProcedures.remove(val) } else { previousProcedures.insert(val) }
                                }
                                .padding(.horizontal, Theme.Spacing.xl)

                                profileChipGroup(title: "Health considerations",
                                                 options: ProfileSelectionCatalog.healthFlagOptions, selected: Array(healthFlags),
                                                 multiSelect: true) { val in
                                    if healthFlags.contains(val) { healthFlags.remove(val) } else { healthFlags.insert(val) }
                                }
                                .padding(.horizontal, Theme.Spacing.xl)
                            }
                            .padding(.top, 8)

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
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .forceUIKitNavigationBarHidden()
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
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: Theme.IconSize.profileAvatar, height: Theme.IconSize.profileAvatar)
                                    .clipShape(Circle())
                            } placeholder: {
                                ProgressView()
                                    .frame(width: Theme.IconSize.profileAvatar, height: Theme.IconSize.profileAvatar)
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
                gender = profile.gender
                ageRange = profile.ageRange
                raceEthnicity = profile.raceEthnicity
                aestheticGoals = Set(profile.aestheticGoals ?? [])
                bodyAreas = Set(profile.bodyAreasOfInterest ?? [])
                proceduresOfInterest = Set(profile.proceduresOfInterest ?? [])
                previousProcedures = Set(profile.previousProcedures ?? [])
                healthFlags = Set(profile.healthFlags ?? [])
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
            var imageData: Data?
            if let selectedData = selectedImageData {
                imageData = selectedData
            }

            _ = try await profileService.updateUserProfile(
                fullName: fullName.isEmpty ? nil : fullName,
                email: email.isEmpty ? nil : email,
                phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                zipCode: zipCode.isEmpty ? nil : zipCode,
                profileImageData: imageData,
                gender: gender,
                ageRange: ageRange,
                raceEthnicity: raceEthnicity,
                aestheticGoals: aestheticGoals.isEmpty ? nil : Array(aestheticGoals),
                proceduresOfInterest: proceduresOfInterest.isEmpty ? nil : Array(proceduresOfInterest),
                previousProcedures: previousProcedures.isEmpty ? nil : Array(previousProcedures),
                healthFlags: healthFlags.isEmpty ? nil : Array(healthFlags),
                bodyAreasOfInterest: bodyAreas.isEmpty ? nil : Array(bodyAreas)
            )

            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save profile: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    // MARK: - Personalization UI Helpers

    private func profileSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Theme.Colors.textProfilePrimary)
            .padding(.top, 4)
    }

    private func profileChipGroup(title: String, options: [String], selected: [String],
                                   multiSelect: Bool, onTap: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.textProfilePrimary.opacity(0.6))

            profileChipFlow(options: options, selected: selected, onTap: onTap)
        }
    }

    private func profileChipFlow(options: [String], selected: [String],
                                  onTap: @escaping (String) -> Void) -> some View {
        var rows: [[String]] = [[]]
        for option in options {
            let approxWidth = CGFloat(option.count) * 7.5 + 28
            let rowWidth = rows.last!.reduce(CGFloat(0)) { $0 + CGFloat($1.count) * 7.5 + 36 }
            let screenWidth = UIScreen.main.bounds.width - CGFloat(Theme.Spacing.xl) * 2 - 4
            if rowWidth + approxWidth > screenWidth && !rows.last!.isEmpty {
                rows.append([option])
            } else {
                rows[rows.count - 1].append(option)
            }
        }
        return VStack(alignment: .leading, spacing: 7) {
            ForEach(rows.indices, id: \.self) { rowIdx in
                HStack(spacing: 7) {
                    ForEach(rows[rowIdx], id: \.self) { option in
                        let isOn = selected.contains(option)
                        Button { onTap(option) } label: {
                            Text(option)
                                .font(.system(size: 12))
                                .foregroundColor(isOn ? Theme.Colors.primaryProfile : Theme.Colors.textProfilePrimary.opacity(0.65))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(isOn ? Theme.Colors.primaryProfile.opacity(0.1) : Color.white)
                                .cornerRadius(20)
                                .overlay(
                                    Capsule().stroke(
                                        isOn ? Theme.Colors.primaryProfile.opacity(0.6) : Theme.Colors.borderLight,
                                        lineWidth: 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

#Preview {
    EditProfileView()
}
