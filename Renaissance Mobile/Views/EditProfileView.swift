//
//  EditProfileView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/2/25.
//

import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var fullName: String = "Sarah Anderson"
    @State private var email: String = "sarah.anderson@email.com"
    @State private var phoneNumber: String = "+1 (555) 123-4567"

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.backgroundProfile
                    .ignoresSafeArea()

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
                    Image(systemName: "person.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.textProfilePrimary.opacity(0.6))
                )

            // Edit Button
            Button(action: {
                // Handle avatar edit
            }) {
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
            // Save profile changes
            dismiss()
        }) {
            Text("Save Changes")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.black)
                .cornerRadius(Theme.CornerRadius.medium)
        }
    }
}

#Preview {
    EditProfileView()
}
