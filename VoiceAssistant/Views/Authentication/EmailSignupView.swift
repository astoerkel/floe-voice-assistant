//
//  EmailSignupView.swift
//  VoiceAssistant
//
//  Created by Claude on 28.07.25.
//

import SwiftUI

struct EmailSignupView: View {
    @ObservedObject var apiClient: SimpleAPIClient
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let onBackToWelcome: () -> Void
    let onSwitchToLogin: () -> Void
    
    @StateObject private var themeManager = ThemeManager.shared
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var agreedToTerms: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, email, password, confirmPassword
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
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.themeMode == .light ? .black : .white)
                    
                    Text("Join Floe and start your voice assistant journey")
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
                        // Name field
                        AuthTextField(
                            title: "Full Name",
                            text: $name,
                            placeholder: "Enter your full name",
                            keyboardType: .default,
                            textContentType: .name,
                            isFocused: focusedField == .name
                        )
                        .focused($focusedField, equals: .name)
                        .onSubmit {
                            focusedField = .email
                        }
                        
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
                            placeholder: "Create a secure password",
                            textContentType: .newPassword,
                            isSecure: true,
                            isFocused: focusedField == .password
                        )
                        .focused($focusedField, equals: .password)
                        .onSubmit {
                            focusedField = .confirmPassword
                        }
                        
                        // Confirm password field
                        AuthTextField(
                            title: "Confirm Password",
                            text: $confirmPassword,
                            placeholder: "Confirm your password",
                            textContentType: .newPassword,
                            isSecure: true,
                            isFocused: focusedField == .confirmPassword
                        )
                        .focused($focusedField, equals: .confirmPassword)
                        .onSubmit {
                            focusedField = nil
                            if canSignUp {
                                signUp()
                            }
                        }
                        
                        // Password requirements
                        if !password.isEmpty {
                            PasswordRequirementsView(password: password)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // Terms agreement
                    Button(action: {
                        agreedToTerms.toggle()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                .font(.title2)
                                .foregroundColor(agreedToTerms ? .blue : .secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                (Text("I agree to the ") +
                                 Text("Terms of Service").foregroundColor(.blue) +
                                 Text(" and ") +
                                 Text("Privacy Policy").foregroundColor(.blue))
                                    .font(.body)
                                    .foregroundColor(themeManager.themeMode == .light ? .black : .white)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // Sign up button
                    Button(action: signUp) {
                        Group {
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text("Creating Account...")
                                }
                            } else {
                                Text("Create Account")
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: canSignUp ? [.blue, .purple] : [.gray, .gray]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                    }
                    .disabled(!canSignUp || isLoading)
                    .padding(.horizontal, 40)
                    
                    // Switch to login
                    Button(action: onSwitchToLogin) {
                        (Text("Already have an account? ") +
                         Text("Sign in").foregroundColor(.blue))
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
    
    private var canSignUp: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidEmail(email) &&
        password.count >= 8 &&
        password == confirmPassword &&
        agreedToTerms
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func signUp() {
        guard canSignUp else { return }
        
        isLoading = true
        errorMessage = nil
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Call the API client to register
        apiClient.registerWithEmail(
            email: trimmedEmail,
            password: password,
            name: trimmedName
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success:
                    // Registration successful - the coordinator will handle the UI transition
                    print("✅ Email registration successful")
                case .failure(let error):
                    showError("Registration failed: \(error.localizedDescription)")
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

// MARK: - Auth Text Field
struct AuthTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var isSecure: Bool = false
    let isFocused: Bool
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.themeMode == .light ? .black : .white)
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textContentType(textContentType)
            .keyboardType(keyboardType)
            .autocapitalization(keyboardType == .emailAddress ? .none : .words)
            .disableAutocorrection(keyboardType == .emailAddress)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.themeMode == .light ? Color.white : Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isFocused ? Color.blue : (themeManager.themeMode == .light ? Color.black.opacity(0.1) : Color.white.opacity(0.2)),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
            )
        }
    }
}

// MARK: - Password Requirements View
struct PasswordRequirementsView: View {
    let password: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password Requirements:")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            RequirementRow(
                text: "At least 8 characters",
                isMet: password.count >= 8
            )
            
            RequirementRow(
                text: "Contains uppercase letter",
                isMet: password.rangeOfCharacter(from: .uppercaseLetters) != nil
            )
            
            RequirementRow(
                text: "Contains lowercase letter",
                isMet: password.rangeOfCharacter(from: .lowercaseLetters) != nil
            )
            
            RequirementRow(
                text: "Contains number or symbol",
                isMet: password.rangeOfCharacter(from: .decimalDigits.union(.punctuationCharacters).union(.symbols)) != nil
            )
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Requirement Row
struct RequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .green : .secondary)
                .font(.body)
            
            Text(text)
                .font(.body)
                .foregroundColor(isMet ? .green : .secondary)
            
            Spacer()
        }
    }
}


#Preview {
    EmailSignupView(
        apiClient: SimpleAPIClient.shared,
        isLoading: .constant(false),
        errorMessage: .constant(nil),
        onBackToWelcome: {},
        onSwitchToLogin: {}
    )
}