//
//  VoiceAssistantApp.swift
//  VoiceAssistant
//
//  Created by Amit Störkel on 16.07.25.
//

import SwiftUI

@main
struct VoiceAssistantApp: App {
    @StateObject private var apiClient = APIClient.shared
    @StateObject private var oauthManager = OAuthManager()
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "onboarding_completed")
    @State private var showDashboard = UserDefaults.standard.bool(forKey: "show_dashboard")
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingCoordinator(apiClient: apiClient)
                        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                            hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "onboarding_completed")
                        }
                } else if apiClient.isAuthenticated {
                    if showDashboard {
                        HomeDashboardView()
                            .environmentObject(WatchConnector.shared)
                    } else {
                        ContentView()
                            .environmentObject(WatchConnector.shared)
                    }
                } else {
                    AuthenticationView(apiClient: apiClient)
                }
            }
            .onOpenURL { url in
                handleOAuthCallback(url: url)
            }
        }
    }
    
    private func handleOAuthCallback(url: URL) {
        guard url.scheme == "voiceassistant",
              url.host == "oauth" else {
            return
        }
        
        // Parse URL components
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems
        
        if let success = queryItems?.first(where: { $0.name == "success" })?.value,
           let token = queryItems?.first(where: { $0.name == "token" })?.value {
            
            // Store the JWT token
            UserDefaults.standard.set(token, forKey: "jwt_token")
            
            // Update API client authentication
            apiClient.setAuthToken(token)
            
            // Refresh OAuth manager status
            oauthManager.refreshIntegrations()
            
            // Show success message
            print("✅ OAuth completed successfully: \(success)")
            
        } else if let error = queryItems?.first(where: { $0.name == "error" })?.value {
            // Handle error
            print("❌ OAuth error: \(error)")
            oauthManager.errorMessage = "OAuth failed: \(error)"
        }
    }
}
