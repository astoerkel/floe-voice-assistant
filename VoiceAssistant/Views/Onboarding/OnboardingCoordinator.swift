//
//  OnboardingCoordinator.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import SwiftUI

enum OnboardingStep {
    case welcome
    case permissions
    case integrations
    case complete
}

struct OnboardingCoordinator: View {
    @State private var currentStep: OnboardingStep = .welcome
    @StateObject private var authViewModel = AuthViewModel()
    @ObservedObject var apiClient: APIClient
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background with particles
                Color.black.ignoresSafeArea()
                ParticleBackgroundView(isVoiceActive: false, isAudioPlaying: false, audioLevel: 0.0)
                
                switch currentStep {
                case .welcome:
                    WelcomeCarouselView(onContinue: { currentStep = .permissions })
                case .permissions:
                    PermissionsFlowView(onComplete: { currentStep = .integrations })
                case .integrations:
                    IntegrationsSetupView(apiClient: apiClient, onComplete: { currentStep = .complete })
                case .complete:
                    OnboardingCompleteView(apiClient: apiClient)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: currentStep)
        }
    }
}

// MARK: - AuthViewModel
@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func showError(_ message: String) {
        errorMessage = message
        
        // Clear error after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.errorMessage = nil
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
}

#Preview {
    OnboardingCoordinator(apiClient: APIClient())
}