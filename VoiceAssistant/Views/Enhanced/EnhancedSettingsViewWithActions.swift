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
        EnhancedSettingsView(
            onClearHistory: { showClearHistoryAlert = true },
            onLogout: { showLogoutAlert = true }
        )
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
        // Use the APIClient's logout method which properly handles all cleanup
        APIClient.shared.logout { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Logout successful")
                case .failure(let error):
                    print("⚠️ Logout error (continuing anyway): \(error)")
                }
                
                // Clear additional local data
                UserDefaults.standard.removeObject(forKey: "development_mode")
                UserDefaults.standard.removeObject(forKey: "onboarding_completed")
                UserDefaults.standard.removeObject(forKey: "user_preferences")
                UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.sessionId)
                UserDefaults.standard.removeObject(forKey: "user_id")
                UserDefaults.standard.removeObject(forKey: "user_email")
                UserDefaults.standard.removeObject(forKey: "user_name")
                
                // Clear conversation history
                conversationHistory.removeAll()
                
                // Clear OAuth tokens from keychain
                Task {
                    try? await KeychainService.shared.delete(key: "jwt_token")
                    try? await KeychainService.shared.delete(key: "refresh_token")
                }
                
                // Haptic feedback
                HapticManager.shared.commandWarning()
                
                // Dismiss settings
                onDismiss()
                
                print("🔓 User logged out successfully")
            }
        }
    }
}

#Preview {
    EnhancedSettingsViewWithActions(
        conversationHistory: .constant([]),
        onDismiss: {}
    )
}