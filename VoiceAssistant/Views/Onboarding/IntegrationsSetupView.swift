//
//  IntegrationsSetupView.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import SwiftUI

struct IntegrationsSetupView: View {
    @ObservedObject var apiClient: APIClient
    let onComplete: () -> Void
    @ObservedObject private var oauthManager = OAuthManager.shared
    @State private var showAuthenticationFirst = false
    
    var body: some View {
        VStack(spacing: 40) {
            // Back button
            HStack {
                Button("Back") {
                    // Handle back navigation
                }
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .padding(.leading, 20)
                
                Spacer()
            }
            .padding(.top, 60)
            
            // Header
            VStack(spacing: 20) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Connect Services")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Connect your favorite services to get more from your voice assistant. You can skip this step and add them later.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Authentication required notice
            if !apiClient.isAuthenticated {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.orange)
                        Text("Authentication Required")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Text("Please sign in first to connect external services.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal, 20)
            }
            
            // Integration cards
            VStack(spacing: 16) {
                IntegrationCard(
                    service: .googleCalendar,
                    isConnected: oauthManager.isConnected(.googleCalendar),
                    isEnabled: apiClient.isAuthenticated,
                    onConnect: { await oauthManager.connectGoogleCalendar() }
                )
                
                IntegrationCard(
                    service: .gmail,
                    isConnected: oauthManager.isConnected(.gmail),
                    isEnabled: apiClient.isAuthenticated,
                    onConnect: { await oauthManager.connectGmail() }
                )
                
                IntegrationCard(
                    service: .airtable,
                    isConnected: oauthManager.isConnected(.airtable),
                    isEnabled: apiClient.isAuthenticated,
                    onConnect: { await oauthManager.connectAirtable() }
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                if !apiClient.isAuthenticated {
                    Button(action: {
                        showAuthenticationFirst = true
                    }) {
                        HStack {
                            Image(systemName: "person.circle")
                                .font(.title2)
                            Text("Sign In First")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(30)
                    }
                }
                
                // Continue/Skip button
                Button(action: onComplete) {
                    HStack {
                        Text(apiClient.isAuthenticated ? "Continue" : "Skip for Now")
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
                
                if !apiClient.isAuthenticated {
                    Text("Don't worry, you can connect services later in settings")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .padding(.bottom, 50)
        }
        .environmentObject(oauthManager)
        .sheet(isPresented: $showAuthenticationFirst) {
            AuthenticationView(apiClient: apiClient)
        }
    }
}

// MARK: - Service Integration Models

enum IntegrationServiceType: String, CaseIterable {
    case googleCalendar = "google_calendar"
    case gmail = "gmail"
    case airtable = "airtable"
    
    var displayName: String {
        switch self {
        case .googleCalendar: return "Google Calendar"
        case .gmail: return "Gmail"
        case .airtable: return "Airtable"
        }
    }
    
    var icon: String {
        switch self {
        case .googleCalendar: return "calendar"
        case .gmail: return "envelope"
        case .airtable: return "table"
        }
    }
    
    var description: String {
        switch self {
        case .googleCalendar: return "Manage your calendar events and meetings"
        case .gmail: return "Read and send emails with voice commands"
        case .airtable: return "Manage tasks and projects"
        }
    }
    
    var color: Color {
        switch self {
        case .googleCalendar: return .blue
        case .gmail: return .red
        case .airtable: return .green
        }
    }
}

struct ConnectedService: Identifiable {
    let id = UUID()
    let service: IntegrationServiceType
    let isConnected: Bool
    let connectedAt: Date?
}

// MARK: - Local OAuth Manager Extension

extension OAuthManager {
    func isConnected(_ service: IntegrationServiceType) -> Bool {
        return integrations.contains { $0.type == service.rawValue && $0.isActive }
    }
    
    func connectGoogleCalendar() async {
        await connectGoogleServices()
    }
    
    func connectGmail() async {
        await connectGoogleServices()
    }
    
    func connectAirtable() async {
        await connectAirtableServices()
    }
}

struct IntegrationCard: View {
    let service: IntegrationServiceType
    let isConnected: Bool
    let isEnabled: Bool
    let onConnect: () async -> Void
    
    @EnvironmentObject var oauthManager: OAuthManager
    @State private var isConnecting = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Service icon
            Image(systemName: service.icon)
                .font(.system(size: 24))
                .foregroundColor(isConnected ? .white : service.color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(isConnected ? service.color : Color.white.opacity(0.1))
                )
            
            // Service info
            VStack(alignment: .leading, spacing: 4) {
                Text(service.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(service.description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Connection status/button
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            } else {
                Button(action: {
                    guard isEnabled else { return }
                    Task {
                        isConnecting = true
                        await onConnect()
                        isConnecting = false
                    }
                }) {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Connect")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                    }
                    .foregroundColor(isEnabled ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        service.color.opacity(isEnabled ? 1.0 : 0.3)
                    )
                    .cornerRadius(20)
                }
                .disabled(!isEnabled || isConnecting)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ParticleBackgroundView(isVoiceActive: false, isAudioPlaying: false, audioLevel: 0.0)
        IntegrationsSetupView(apiClient: APIClient(), onComplete: {})
    }
}