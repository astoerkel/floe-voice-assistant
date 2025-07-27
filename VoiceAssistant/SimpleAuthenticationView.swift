import SwiftUI
import AuthenticationServices

struct SimpleAuthenticationView: View {
    @ObservedObject var apiClient: SimpleAPIClient
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo/Title
                VStack(spacing: 16) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Floe")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Simple Voice Assistant")
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
                .padding(.bottom, 60)
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
                        // Authentication successful
                        print("✅ Authentication successful")
                    case .failure(let error):
                        showError("Authentication failed: \(error.localizedDescription)")
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
                    showError("Apple Sign In was cancelled or failed. Please try again.")
                } else {
                    showError("Sign in failed: \(error.localizedDescription)")
                }
            } else {
                showError("Sign in failed: \(error.localizedDescription)")
            }
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
    SimpleAuthenticationView(apiClient: SimpleAPIClient())
}