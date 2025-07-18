//
//  AuthenticationView.swift
//  VoiceAssistant
//
//  Created by Claude on 17.07.25.
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @ObservedObject var apiClient: APIClient
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                // Particle effect background
                ParticleBackgroundView(isVoiceActive: false, isAudioPlaying: false)
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Logo/Title
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Sora")
                            .font(.custom("Corinthia", size: 64))
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("AI-powered voice assistant")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    // Authentication Section
                    VStack(spacing: 24) {
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.body)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        // Development bypass button (for simulator testing)
                        #if DEBUG
                        Button("Skip Authentication (Development)") {
                            // Set development mode flag
                            UserDefaults.standard.set(true, forKey: "development_mode")
                            
                            // Create mock tokens for development
                            let mockAccessToken = "mock_access_token_for_development"
                            let mockRefreshToken = "mock_refresh_token_for_development"
                            
                            // Save mock tokens to simulate authentication
                            UserDefaults.standard.set(mockAccessToken, forKey: "voice_assistant_access_token")
                            UserDefaults.standard.set(mockRefreshToken, forKey: "voice_assistant_refresh_token")
                            
                            // Update API client authentication state
                            DispatchQueue.main.async {
                                apiClient.isAuthenticated = true
                            }
                        }
                        .font(.body)
                        .foregroundColor(.yellow)
                        .padding(.vertical, 8)
                        #endif
                        
                        // Apple Sign In Button
                        SignInWithAppleButton(
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                handleSignInWithAppleResult(result)
                            }
                        )
                        .signInWithAppleButtonStyle(
                            colorScheme == .dark ? .white : .black
                        )
                        .frame(height: 50)
                        .cornerRadius(25)
                        .disabled(isLoading)
                        
                        // Loading indicator
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Signing in...")
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        // Privacy notice
                        VStack(spacing: 8) {
                            Text("By continuing, you agree to our")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                            
                            HStack {
                                Text("Terms of Service")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .underline()
                                
                                Text("and")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text("Privacy Policy")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .underline()
                            }
                        }
                        .padding(.top, 16)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                }
            }
        }
    }
    
    private func handleSignInWithAppleResult(_ result: Result<ASAuthorization, Error>) {
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
                        // Authentication successful - the APIClient will handle the token storage
                        print("✅ Authentication successful")
                    case .failure(let error):
                        showError("Authentication failed: \(error.localizedDescription)")
                    }
                }
            }
            
        case .failure(let error):
            showError("Sign in failed: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        isLoading = false
        
        // Clear error message after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            errorMessage = nil
        }
    }
}

#Preview {
    AuthenticationView(apiClient: APIClient())
}