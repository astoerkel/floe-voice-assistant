//
//  OnboardingCompleteView.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import SwiftUI
import AuthenticationServices

struct OnboardingCompleteView: View {
    @ObservedObject var apiClient: APIClient
    @State private var showingSignIn = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Success animation
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .opacity(0.2)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                }
                
                Text("All Set!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("You're ready to start using your voice assistant.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Sign in section (if not authenticated)
            if !apiClient.isAuthenticated {
                VStack(spacing: 20) {
                    Text("Sign in to get started")
                        .font(.headline)
                        .foregroundColor(.white)
                    
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
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Start using button
            Button(action: {
                // Complete onboarding
                UserDefaults.standard.set(true, forKey: "onboarding_completed")
                
                // If authenticated, this will trigger the main app
                if !apiClient.isAuthenticated {
                    showingSignIn = true
                }
            }) {
                HStack {
                    Text(apiClient.isAuthenticated ? "Start Using Floe" : "Continue to Sign In")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Image(systemName: "arrow.right")
                        .font(.title2)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(30)
                .shadow(color: Color.blue.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .padding(.bottom, 50)
        }
        .sheet(isPresented: $showingSignIn) {
            AuthenticationView(apiClient: apiClient)
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
                        // Authentication successful
                        print("✅ Authentication successful")
                        // Mark onboarding as complete
                        UserDefaults.standard.set(true, forKey: "onboarding_completed")
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
    ZStack {
        Color.black.ignoresSafeArea()
        ParticleBackgroundView(isVoiceActive: false, isAudioPlaying: false)
        OnboardingCompleteView(apiClient: APIClient())
    }
}