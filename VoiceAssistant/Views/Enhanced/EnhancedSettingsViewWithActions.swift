//
//  EnhancedSettingsViewWithActions.swift
//  VoiceAssistant
//
//  Created by Claude on 24.07.25.
//

import SwiftUI

struct EnhancedSettingsViewWithActions: View {
    @Binding var conversationHistory: [ConversationMessage]
    let onDismiss: () -> Void
    @ObservedObject private var apiClient = APIClient.shared
    @State private var showClearHistoryAlert = false
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // Original Enhanced Settings View
                EnhancedSettingsView()
                
                // Additional Actions Section
                VStack(spacing: 16) {
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    // Clear Chat History Button
                    Button(action: { showClearHistoryAlert = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.title3)
                            Text("Clear Chat History")
                                .font(.headline)
                            Spacer()
                        }
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Logout Button
                    Button(action: { showLogoutAlert = true }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .font(.title3)
                            Text("Logout")
                                .font(.headline)
                            Spacer()
                        }
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Clear Chat History", isPresented: $showClearHistoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearChatHistory()
            }
        } message: {
            Text("Are you sure you want to delete all conversation history? This action cannot be undone.")
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                logout()
            }
        } message: {
            Text("Are you sure you want to logout? You'll need to sign in again to use the app.")
        }
    }
    
    private func clearChatHistory() {
        // Clear conversation history
        conversationHistory.removeAll()
        
        // Clear from UserDefaults if stored there
        UserDefaults.standard.removeObject(forKey: "conversation_history")
        
        // Haptic feedback
        HapticManager.shared.commandSuccess()
        
        // Dismiss after clearing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onDismiss()
        }
    }
    
    private func logout() {
        // Clear authentication tokens
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.accessToken)
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.refreshToken)
        UserDefaults.standard.removeObject(forKey: "development_mode")
        
        // Clear user data
        UserDefaults.standard.removeObject(forKey: "onboarding_completed")
        UserDefaults.standard.removeObject(forKey: "user_preferences")
        
        // Clear conversation history
        conversationHistory.removeAll()
        
        // Reset API client - logout will be handled by the APIClient observer
        // The APIClient will automatically update its isAuthenticated state when tokens are removed
        
        // Haptic feedback
        HapticManager.shared.commandWarning()
        
        // Dismiss settings
        onDismiss()
        
        // Note: The app should handle the logout state change and show appropriate UI
        // This is typically handled by the main app view observing apiClient.isAuthenticated
    }
}

#Preview {
    EnhancedSettingsViewWithActions(
        conversationHistory: .constant([]),
        onDismiss: {}
    )
}