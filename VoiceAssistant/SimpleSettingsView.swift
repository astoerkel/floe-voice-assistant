//
//  SimpleSettingsView.swift
//  VoiceAssistant
//
//  Created on 27.01.25.
//

import SwiftUI
import AuthenticationServices

struct SimpleSettingsView: View {
    @StateObject private var apiClient = SimpleAPIClient.shared
    @ObservedObject var conversationManager: SimpleConversationManager
    @State private var showingClearHistoryAlert = false
    @State private var showingLogoutAlert = false
    @State private var userEmail: String = ""
    @State private var userName: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                // User Information Section
                if apiClient.isAuthenticated {
                    Section {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.accentColor)
                                .frame(width: 60, height: 60)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if !userName.isEmpty {
                                    Text(userName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                } else if !userEmail.isEmpty {
                                    // Extract name from email if no name is provided
                                    Text(extractNameFromEmail(userEmail))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                } else {
                                    Text("Apple User")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if !userEmail.isEmpty {
                                    Text(userEmail)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Signed in with Apple")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Account")
                    }
                }
                
                // Chat History Section
                Section {
                    HStack {
                        Label("Chat History", systemImage: "message.fill")
                        Spacer()
                        Text("\(conversationManager.conversationHistory.count) messages")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    Button(action: {
                        showingClearHistoryAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Chat History")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(conversationManager.conversationHistory.isEmpty)
                } header: {
                    Text("Data")
                } footer: {
                    Text("Clearing chat history will permanently delete all conversation messages.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Account Actions Section
                if apiClient.isAuthenticated {
                    Section {
                        Button(action: {
                            showingLogoutAlert = true
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                                Text("Sign Out")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // App Information Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            loadUserInfo()
        }
        .alert("Clear Chat History", isPresented: $showingClearHistoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearChatHistory()
            }
        } message: {
            Text("Are you sure you want to clear all chat history? This action cannot be undone.")
        }
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    private func loadUserInfo() {
        // Load user info from SimpleAPIClient
        let userInfo = apiClient.getCurrentUserInfo()
        
        if let email = userInfo.email {
            userEmail = email
        }
        
        if let name = userInfo.name {
            userName = name
        }
    }
    
    private func clearChatHistory() {
        withAnimation {
            conversationManager.clearHistory()
        }
    }
    
    private func signOut() {
        apiClient.logout { result in
            switch result {
            case .success:
                // Clear cached user info
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: "cached_user_email")
                defaults.removeObject(forKey: "cached_user_name")
                
                // Clear user info from view
                userEmail = ""
                userName = ""
                
                // Also clear conversation history on logout
                conversationManager.clearHistory()
                
            case .failure(let error):
                print("❌ Logout failed: \(error)")
            }
        }
    }
    
    private func extractNameFromEmail(_ email: String) -> String {
        // Extract the part before @ and format it nicely
        let emailPrefix = email.split(separator: "@").first ?? ""
        let name = String(emailPrefix)
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        
        // Capitalize each word
        return name.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}

// Preview
struct SimpleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleSettingsView(conversationManager: SimpleConversationManager())
    }
}