//
//  SignUpView.swift
//  Renaissance Mobile
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false

    var onSignUp: (() -> Void)?
    var onSignIn: (() -> Void)?
    var prefillEmail: String = ""

    private var isFormValid: Bool {
        !fullName.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        password == confirmPassword
    }

    private var isBusy: Bool { authViewModel.isLoading }

    private var fieldStroke: Color { Color(hex: "#D4CCFF") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Full Name
                    inputField {
                        TextField(
                            "",
                            text: $fullName,
                            prompt: Text("Full Name").foregroundColor(Color(hex: "#7B6FC0").opacity(0.7))
                        )
                        .font(.custom("PlusJakartaSans-Regular", size: 16))
                        .foregroundColor(Color(hex: "#2D2575"))
                        .autocapitalization(.words)
                    }
                    .padding(.top, 28)
                    .padding(.horizontal, 24)

                    // Email
                    inputField {
                        TextField(
                            "",
                            text: $email,
                            prompt: Text("Email").foregroundColor(Color(hex: "#7B6FC0").opacity(0.7))
                        )
                        .font(.custom("PlusJakartaSans-Regular", size: 16))
                        .foregroundColor(Color(hex: "#2D2575"))
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 24)

                    // Password
                    inputField {
                        HStack {
                            Group {
                                if isPasswordVisible {
                                    TextField(
                                        "",
                                        text: $password,
                                        prompt: Text("Password").foregroundColor(Color(hex: "#7B6FC0").opacity(0.7))
                                    )
                                } else {
                                    SecureField(
                                        "",
                                        text: $password,
                                        prompt: Text("Password").foregroundColor(Color(hex: "#7B6FC0").opacity(0.7))
                                    )
                                }
                            }
                            .font(.custom("PlusJakartaSans-Regular", size: 16))
                            .foregroundColor(Color(hex: "#2D2575"))

                            Button { isPasswordVisible.toggle() } label: {
                                Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "#6C63FF"))
                            }
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 24)

                    // Confirm Password
                    inputField(strokeOverride: !confirmPassword.isEmpty && password != confirmPassword
                        ? Color.red.opacity(0.5) : nil) {
                        HStack {
                            Group {
                                if isConfirmPasswordVisible {
                                    TextField(
                                        "",
                                        text: $confirmPassword,
                                        prompt: Text("Confirm Password").foregroundColor(Color(hex: "#7B6FC0").opacity(0.7))
                                    )
                                } else {
                                    SecureField(
                                        "",
                                        text: $confirmPassword,
                                        prompt: Text("Confirm Password").foregroundColor(Color(hex: "#7B6FC0").opacity(0.7))
                                    )
                                }
                            }
                            .font(.custom("PlusJakartaSans-Regular", size: 16))
                            .foregroundColor(Color(hex: "#2D2575"))

                            Button { isConfirmPasswordVisible.toggle() } label: {
                                Image(systemName: isConfirmPasswordVisible ? "eye" : "eye.slash")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "#6C63FF"))
                            }
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 24)

                    // Password mismatch
                    if !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Passwords do not match")
                            .font(.custom("PlusJakartaSans-Regular", size: 12))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 6)
                            .padding(.bottom, 10)
                    } else {
                        Color.clear.frame(height: 24)
                    }

                    // Auth error
                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.custom("PlusJakartaSans-Regular", size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Create account button
                    Button {
                        Task {
                            await authViewModel.signUp(email: email, password: password)
                            if authViewModel.isAuthenticated { onSignUp?() }
                        }
                    } label: {
                        Group {
                            if isBusy {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Account")
                                    .font(.custom("PlusJakartaSans-SemiBold", size: 16).weight(.bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isFormValid ? Color(hex: "#2D2575") : Color(hex: "#2D2575").opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                    .disabled(isBusy || !isFormValid)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                    // Sign in link
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(.custom("PlusJakartaSans-Regular", size: 14))
                            .foregroundColor(Color(hex: "#7B6FC0"))

                        Button { onSignIn?() } label: {
                            Text("Sign in")
                                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                .foregroundColor(Color(hex: "#6C63FF"))
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(Color(hex: "#FAFAFF"))
            .onAppear {
                if !prefillEmail.isEmpty { email = prefillEmail }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Create account")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 18))
                        .foregroundColor(Color(hex: "#2D2575"))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "#2D2575"))
                    }
                }
            }
        }
    }

    private func inputField<Content: View>(
        strokeOverride: Color? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(strokeOverride ?? fieldStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    SignUpView()
        .environment(AuthViewModel())
}
