//
//  AuthenticationCoordinator.swift
//  VoiceAssistant
//
//  Created by Claude on 28.07.25.
//

import SwiftUI
import AuthenticationServices

enum AuthenticationStep {
    case welcome
    case emailSignup
    case emailLogin
    case socialAuth
}

struct AuthenticationCoordinator: View {
    @ObservedObject var apiClient: SimpleAPIClient
    @StateObject private var themeManager = ThemeManager.shared
    @State private var currentStep: AuthenticationStep = .welcome
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive background
                Group {
                    if themeManager.themeMode == .dark || 
                       (themeManager.themeMode == .system && UITraitCollection.current.userInterfaceStyle == .dark) {
                        Color.black
                    } else {
                        Color(red: 0.98, green: 0.98, blue: 0.98)
                    }
                }
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    switch currentStep {
                    case .welcome:
                        WelcomeView(
                            onGetStarted: { currentStep = .socialAuth },
                            onHaveAccount: { currentStep = .emailLogin }
                        )
                    case .emailSignup:
                        EmailSignupView(
                            apiClient: apiClient,
                            isLoading: $isLoading,
                            errorMessage: $errorMessage,
                            onBackToWelcome: { currentStep = .welcome },
                            onSwitchToLogin: { currentStep = .emailLogin }
                        )
                    case .emailLogin:
                        EmailLoginView(
                            apiClient: apiClient,
                            isLoading: $isLoading,
                            errorMessage: $errorMessage,
                            onBackToWelcome: { currentStep = .welcome },
                            onSwitchToSignup: { currentStep = .emailSignup }
                        )
                    case .socialAuth:
                        SocialAuthView(
                            apiClient: apiClient,
                            isLoading: $isLoading,
                            errorMessage: $errorMessage,
                            onBackToWelcome: { currentStep = .welcome },
                            onEmailSignup: { currentStep = .emailSignup },
                            onEmailLogin: { currentStep = .emailLogin }
                        )
                    }
                }
            }
            .animation(.easeInOut(duration: 0.5), value: currentStep)
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    let onGetStarted: () -> Void
    let onHaveAccount: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Logo and branding
            VStack(spacing: 24) {
                // App icon with glow effect
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.3),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 30,
                                endRadius: 100
                            )
                        )
                        .frame(width: 160, height: 160)
                    
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.5), radius: 20, x: 0, y: 0)
                }
                
                VStack(spacing: 16) {
                    Text("Floe")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.themeMode == .light ? .black : .white)
                    
                    Text("Your Personal Voice Assistant")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Features preview
            VStack(spacing: 24) {
                WelcomeFeatureRow(
                    icon: "mic.fill",
                    title: "Natural Voice Interaction",
                    subtitle: "Just speak naturally and get instant responses"
                )
                
                WelcomeFeatureRow(
                    icon: "brain.head.profile",
                    title: "AI-Powered Intelligence",
                    subtitle: "Advanced AI that understands context and learns"
                )
                
                WelcomeFeatureRow(
                    icon: "lock.shield.fill",
                    title: "Privacy First",
                    subtitle: "Your conversations stay secure and private"
                )
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                // Primary CTA - Get started
                Button(action: onGetStarted) {
                    HStack {
                        Text("Get Started")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Image(systemName: "arrow.right")
                            .font(.headline)
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
                
                // Secondary CTA - Sign in
                Button(action: onHaveAccount) {
                    Text("Already have an account? Sign in")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Welcome Feature Row
struct WelcomeFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(themeManager.themeMode == .light ? Color.black.opacity(0.05) : Color.white.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.themeMode == .light ? .black : .white)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview {
    AuthenticationCoordinator(apiClient: SimpleAPIClient.shared)
}