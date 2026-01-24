//
//  UpdatePasswordView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 1/24/26.
//

import SwiftUI

struct UpdatePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var showSuccessAlert = false

    private var isFormValid: Bool {
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 6
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Set new password heading
                    Text("Set new password")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(Theme.Colors.textWelcomePrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        .padding(.bottom, 12)

                    // Subtitle
                    Text("Enter your new password below. Make sure it's at least 6 characters long.")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)

                    // New Password field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if isPasswordVisible {
                                TextField("New Password", text: $newPassword)
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.textWelcomePrimary)
                            } else {
                                SecureField("New Password", text: $newPassword)
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.textWelcomePrimary)
                            }

                            Button(action: {
                                isPasswordVisible.toggle()
                            }) {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#2badee"))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // Confirm Password field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if isConfirmPasswordVisible {
                                TextField("Confirm Password", text: $confirmPassword)
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.textWelcomePrimary)
                            } else {
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.textWelcomePrimary)
                            }

                            Button(action: {
                                isConfirmPasswordVisible.toggle()
                            }) {
                                Image(systemName: isConfirmPasswordVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#2badee"))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    !confirmPassword.isEmpty && newPassword != confirmPassword
                                    ? Color.red.opacity(0.5)
                                    : Color.gray.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)

                    // Password mismatch error
                    if !confirmPassword.isEmpty && newPassword != confirmPassword {
                        Text("Passwords do not match")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                            .padding(.bottom, 16)
                    } else if !newPassword.isEmpty && newPassword.count < 6 {
                        Text("Password must be at least 6 characters")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                            .padding(.bottom, 16)
                    } else {
                        Color.clear.frame(height: 24)
                    }

                    // Error message from auth
                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Update Password button
                    Button(action: {
                        Task {
                            let success = await authViewModel.updatePassword(newPassword: newPassword)
                            if success {
                                showSuccessAlert = true
                            }
                        }
                    }) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.black)
                                .cornerRadius(12)
                        } else {
                            Text("Update Password")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(isFormValid ? Color.black : Color.gray.opacity(0.5))
                                .cornerRadius(12)
                        }
                    }
                    .disabled(authViewModel.isLoading || !isFormValid)
                    .padding(.horizontal, 24)
                }
            }
            .background(Theme.Colors.backgroundWelcome)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Update Password")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Colors.textWelcomePrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        authViewModel.showUpdatePassword = false
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.Colors.textWelcomePrimary)
                    }
                }
            }
            .alert("Password Updated", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your password has been successfully updated. You can now sign in with your new password.")
            }
        }
    }
}

#Preview {
    UpdatePasswordView()
        .environment(AuthViewModel())
}
