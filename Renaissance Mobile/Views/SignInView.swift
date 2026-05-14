//
//  SignInView.swift
//  Renaissance Mobile
//

import SwiftUI

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var showSignUp = false
    @State private var showResetPassword = false

    var onSignIn: (() -> Void)?

    private var isBusy: Bool { authViewModel.isLoading }

    private var fieldStroke: Color { Color(hex: "#D4CCFF") }
    private var fieldBackground: Color { Color.white }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Email field
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
                    .padding(.top, 28)
                    .padding(.horizontal, 24)

                    // Password field
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

                    // Forgot password
                    Button { showResetPassword = true } label: {
                        Text("Forgot your password?")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                            .foregroundColor(Color(hex: "#6C63FF"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                    // Error
                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.custom("PlusJakartaSans-Regular", size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Sign in button
                    Button {
                        Task {
                            await authViewModel.signIn(email: email, password: password)
                            if authViewModel.isAuthenticated { onSignIn?() }
                        }
                    } label: {
                        Group {
                            if isBusy {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Sign in")
                                    .font(.custom("PlusJakartaSans-SemiBold", size: 16).weight(.bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            email.isEmpty || password.isEmpty
                                ? Color(hex: "#2D2575").opacity(0.4)
                                : Color(hex: "#2D2575")
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                    .disabled(isBusy || email.isEmpty || password.isEmpty)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                    // Create account link
                    HStack(spacing: 4) {
                        Text("First time here?")
                            .font(.custom("PlusJakartaSans-Regular", size: 14))
                            .foregroundColor(Color(hex: "#7B6FC0"))

                        Button { showSignUp = true } label: {
                            Text("Create an account")
                                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                .foregroundColor(Color(hex: "#6C63FF"))
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(Color(hex: "#FAFAFF"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Sign in")
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
            .sheet(isPresented: $showSignUp) {
                SignUpView(
                    onSignUp: { showSignUp = false; onSignIn?() },
                    onSignIn: { showSignUp = false }
                )
            }
            .sheet(isPresented: $showResetPassword) {
                ResetPasswordView(onSignIn: { showResetPassword = false })
            }
        }
    }

    private func inputField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(fieldBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(fieldStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    SignInView()
        .environment(AuthViewModel())
}
