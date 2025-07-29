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
    @ObservedObject private var oauthManager = OAuthManager.shared
    @ObservedObject var conversationManager: SimpleConversationManager
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var userManager = SimpleUserManager.shared
    @State private var showingClearHistoryAlert = false
    @State private var showingLogoutAlert = false
    @State private var userEmail: String = ""
    @State private var userName: String = ""
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color based on theme
                Group {
                    if themeManager.themeMode == .dark || 
                       (themeManager.themeMode == .system && UITraitCollection.current.userInterfaceStyle == .dark) {
                        Color.black
                    } else {
                        Color(red: 0.98, green: 0.98, blue: 0.98)
                    }
                }
                .ignoresSafeArea()
                
                Form {
                    // User Information Section - At the very top
                    if apiClient.isAuthenticated {
                        Section {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 60, height: 60)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // Show name from UserManager first, then fallback to cached info
                                    if let profile = userManager.userProfile, let name = profile.name, !name.isEmpty {
                                        Text(name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    } else if !userName.isEmpty {
                                        Text(userName)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    } else if !userEmail.isEmpty {
                                        Text(extractNameFromEmail(userEmail))
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("User")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Show email from UserManager first, then fallback to cached info
                                    if let profile = userManager.userProfile {
                                        Text(profile.email)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    } else if !userEmail.isEmpty {
                                        Text(userEmail)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Loading...")
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
                    
                    // Integrations Section
                    Section {
                    NavigationLink {
                        IntegrationsMenuView()
                    } label: {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 36)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Service Integrations")
                                    .font(.headline)
                                
                                if oauthManager.isGoogleConnected {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                        Text("Google Services Connected")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                } else {
                                    Text("Connect Google, Airtable, and more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if oauthManager.isGoogleConnected || oauthManager.isAirtableConnected {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Integrations")
                }
                
                // Appearance Section
                Section {
                    HStack {
                        Label("Theme", systemImage: "paintbrush.fill")
                        Spacer()
                        Picker("", selection: $themeManager.themeMode) {
                            ForEach(ThemeManager.ThemeMode.allCases, id: \.self) { mode in
                                Label(mode.displayName, systemImage: mode.icon)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .fixedSize()
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose between light, dark, or automatic theme based on system settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            loadUserInfo()
            oauthManager.checkIntegrationStatus()
            
            // Fetch fresh user profile from server
            Task {
                await userManager.fetchUserProfile()
            }
        }
        .onReceive(apiClient.$isAuthenticated) { isAuthenticated in
            print("🔍 Authentication status changed: \(isAuthenticated)")
            if isAuthenticated {
                print("🔍 User authenticated, refreshing user info...")
                loadUserInfo()
            }
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
        
        print("🔍 SimpleSettingsView loadUserInfo:")
        print("🔍 Retrieved email: \(userInfo.email ?? "nil")")
        print("🔍 Retrieved name: \(userInfo.name ?? "nil")")
        
        if let email = userInfo.email {
            userEmail = email
            print("🔍 Set userEmail to: \(userEmail)")
        }
        
        if let name = userInfo.name {
            userName = name
            print("🔍 Set userName to: \(userName)")
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
        SimpleSettingsView(conversationManager: SimpleConversationManager(), isPresented: .constant(true))
    }
}