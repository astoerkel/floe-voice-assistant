//
//  EmailLoginView.swift
//  VoiceAssistant
//
//  Created by Claude on 28.07.25.
//

import SwiftUI

struct EmailLoginView: View {
    @ObservedObject var apiClient: SimpleAPIClient
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let onBackToWelcome: () -> Void
    let onSwitchToSignup: () -> Void
    
    @StateObject private var themeManager = ThemeManager.shared
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var rememberMe: Bool = true
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Button(action: onBackToWelcome) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)
                
                VStack(spacing: 12) {
                    Text("Welcome Back")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.themeMode == .light ? .black : .white)
                    
                    Text("Sign in to continue your voice assistant experience")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    // Error message
                    if let errorMessage = errorMessage {
                        ErrorMessageView(message: errorMessage)
                            .padding(.horizontal, 40)
                    }
                    
                    // Form fields
                    VStack(spacing: 20) {
                        // Email field
                        AuthTextField(
                            title: "Email",
                            text: $email,
                            placeholder: "Enter your email address",
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            isFocused: focusedField == .email
                        )
                        .focused($focusedField, equals: .email)
                        .onSubmit {
                            focusedField = .password
                        }
                        
                        // Password field
                        AuthTextField(
                            title: "Password",
                            text: $password,
                            placeholder: "Enter your password",
                            textContentType: .password,
                            isSecure: true,
                            isFocused: focusedField == .password
                        )
                        .focused($focusedField, equals: .password)
                        .onSubmit {
                            focusedField = nil
                            if canSignIn {
                                signIn()
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // Remember me and forgot password
                    HStack {
                        Button(action: {
                            rememberMe.toggle()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                    .foregroundColor(rememberMe ? .blue : .secondary)
                                
                                Text("Remember me")
                                    .font(.body)
                                    .foregroundColor(themeManager.themeMode == .light ? .black : .white)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showError("Password reset will be implemented with the new backend API")
                        }) {
                            Text("Forgot password?")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // Sign in button
                    Button(action: signIn) {
                        Group {
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text("Signing In...")
                                }
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: canSignIn ? [.blue, .purple] : [.gray, .gray]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                    }
                    .disabled(!canSignIn || isLoading)
                    .padding(.horizontal, 40)
                    
                    // Switch to signup
                    Button(action: onSwitchToSignup) {
                        (Text("Don't have an account? ") +
                         Text("Create one").foregroundColor(.blue))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .disabled(isLoading)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            
            Spacer()
        }
    }
    
    private var canSignIn: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        isValidEmail(email)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func signIn() {
        guard canSignIn else { return }
        
        isLoading = true
        errorMessage = nil
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Call the API client to log in
        apiClient.loginWithEmail(
            email: trimmedEmail,
            password: password
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success:
                    // Login successful - the coordinator will handle the UI transition
                    print("✅ Email login successful")
                case .failure(let error):
                    showError("Login failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        
        // Clear error message after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            errorMessage = nil
        }
    }
}

#Preview {
    EmailLoginView(
        apiClient: SimpleAPIClient.shared,
        isLoading: .constant(false),
        errorMessage: .constant(nil),
        onBackToWelcome: {},
        onSwitchToSignup: {}
    )
}