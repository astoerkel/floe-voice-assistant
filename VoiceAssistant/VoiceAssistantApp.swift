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
        }
    }
}
