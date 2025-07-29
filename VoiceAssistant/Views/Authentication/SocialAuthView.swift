//
//  SocialAuthView.swift
//  VoiceAssistant
//
//  Created by Claude on 28.07.25.
//

import SwiftUI
import AuthenticationServices

struct SocialAuthView: View {
    @ObservedObject var apiClient: SimpleAPIClient
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let onBackToWelcome: () -> Void
    let onEmailSignup: () -> Void
    let onEmailLogin: () -> Void
    
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
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
                    Text("Sign in to Floe")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.themeMode == .light ? .black : .white)
                    
                    Text("Choose your preferred sign-in method")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
            }
            
            // Error message
            if let errorMessage = errorMessage {
                ErrorMessageView(message: errorMessage)
                    .padding(.horizontal, 40)
            }
            
            // Social authentication buttons
            VStack(spacing: 16) {
                // Apple Sign In
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                )
                .signInWithAppleButtonStyle(
                    themeManager.themeMode == .light ? .black : .white
                )
                .frame(height: 56)
                .cornerRadius(28)
                .disabled(isLoading)
                
                // Google Sign In Button (placeholder for now)
                Button(action: {
                    // TODO: Implement Google Sign In
                    showError("Google Sign-In coming soon!")
                }) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.title2)
                        
                        Text("Continue with Google")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(themeManager.themeMode == .light ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(themeManager.themeMode == .light ? Color.black.opacity(0.2) : Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 40)
            
            // Divider
            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                
                Text("or")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal, 40)
            
            // Email options
            VStack(spacing: 16) {
                // Email signup
                Button(action: onEmailSignup) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .font(.title2)
                        
                        Text("Create account with email")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(28)
                }
                .disabled(isLoading)
                
                // Email login
                Button(action: onEmailLogin) {
                    Text("Sign in with email")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 40)
            
            // Loading indicator
            if isLoading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.8)
                    Text("Signing in...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 16)
            }
            
            Spacer()
            
            // Terms and privacy
            VStack(spacing: 8) {
                Text("By continuing, you agree to our")
                    .font(.caption)
                    .foregroundColor(.secondary) +
                Text(" Terms of Service")
                    .font(.caption)
                    .foregroundColor(.blue) +
                Text(" and ")
                    .font(.caption)
                    .foregroundColor(.secondary) +
                Text("Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else {
                showError("Invalid Apple ID credential")
                return
            }
            
            guard let identityToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                showError("Unable to fetch identity token")
                return
            }
            
            isLoading = true
            errorMessage = nil
            
            // Create user info dictionary
            var userInfo: [String: Any] = [:]
            if let fullName = appleIDCredential.fullName {
                var nameComponents: [String] = []
                if let givenName = fullName.givenName {
                    nameComponents.append(givenName)
                }
                if let familyName = fullName.familyName {
                    nameComponents.append(familyName)
                }
                if !nameComponents.isEmpty {
                    userInfo["name"] = nameComponents.joined(separator: " ")
                }
            }
            if let email = appleIDCredential.email {
                userInfo["email"] = email
            }
            
            // Call the API client to authenticate
            apiClient.authenticateWithApple(
                idToken: idTokenString,
                user: userInfo.isEmpty ? nil : userInfo
            ) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    switch result {
                    case .success:
                        // Authentication successful - the coordinator will handle the UI transition
                        print("✅ Apple Sign-In successful")
                    case .failure(let error):
                        showError("Apple Sign-In failed: \(error.localizedDescription)")
                    }
                }
            }
            
        case .failure(let error):
            // Handle Apple Sign In errors
            if let nsError = error as NSError? {
                print("❌ Apple Sign In Error Domain: \(nsError.domain)")
                print("❌ Apple Sign In Error Code: \(nsError.code)")
                print("❌ Apple Sign In Error: \(nsError.localizedDescription)")
                
                if nsError.domain == "com.apple.AuthenticationServices.AuthorizationError" && nsError.code == 1000 {
                    showError("Apple Sign-In was cancelled. Please try again.")
                } else {
                    showError("Apple Sign-In failed: \(error.localizedDescription)")
                }
            } else {
                showError("Apple Sign-In failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        isLoading = false
        
        // Clear error message after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            errorMessage = nil
        }
    }
}

// MARK: - Error Message View
struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.body)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(16)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    SocialAuthView(
        apiClient: SimpleAPIClient.shared,
        isLoading: .constant(false),
        errorMessage: .constant(nil),
        onBackToWelcome: {},
        onEmailSignup: {},
        onEmailLogin: {}
    )
}