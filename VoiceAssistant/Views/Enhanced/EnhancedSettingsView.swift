//
//  EnhancedSettingsView.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import SwiftUI
import Foundation

// MARK: - Supporting Models

struct AppUser {
    let id: String
    let name: String
    let email: String
    let profilePictureURL: URL?
    let createdAt: Date
}

struct Subscription {
    let id: String
    let plan: String
    let isActive: Bool
    let expiresAt: Date
}

struct Integration: Identifiable {
    let id: String
    let name: String
    let iconName: String
    let color: Color
    let isConnected: Bool
}

struct VoiceSettings {
    var speed: Float
    var pitch: Float
    var gender: VoiceGender
}

enum VoiceGender {
    case female
    case male
    case neutral
}

// MARK: - ViewModels

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var monthlyCommandsUsed = 0
    @Published var monthlyCommandsLimit = 100
    @Published var integrations: [Integration] = []
    @Published var voiceSettings = VoiceSettings(speed: 1.0, pitch: 1.0, gender: .female)
    @Published var useAppleSpeech = true
    @Published var useWhisperFallback = true
    @Published var showDeleteAccountConfirmation = false
    @Published var preferredName: String = ""
    @Published var isUpdatingPreferences = false
    @Published var preferencesUpdateMessage: String? = nil
    
    func loadSettings() {
        // Load user settings
        loadUserData()
        loadUsageData()
        loadIntegrations()
        loadVoiceSettings()
    }
    
    private func loadUserData() {
        // Load preferred name from UserDefaults first
        preferredName = UserDefaults.standard.string(forKey: "preferred_name") ?? ""
        
        // Get authentication status and tokens for debugging
        let isAuth = APIClient.shared.isAuthenticated
        let mainToken = UserDefaults.standard.string(forKey: "voice_assistant_access_token")
        let refreshToken = UserDefaults.standard.string(forKey: "voice_assistant_refresh_token")
        
        print("🔍 Settings loadUserData - isAuthenticated: \(isAuth), mainToken: \(mainToken != nil), refreshToken: \(refreshToken != nil)")
        
        // For now, if authenticated, show a basic authenticated user instead of guest
        if isAuth {
            // Try to decode information from the access token if available
            if let token = mainToken, let decoded = try? decodeJWT(token) {
                print("✅ Decoded token data: \(decoded)")
                
                currentUser = AppUser(
                    id: decoded["sub"] as? String ?? "unknown",
                    name: decoded["name"] as? String ?? (decoded["email"] as? String)?.components(separatedBy: "@").first?.capitalized ?? "Authenticated User",
                    email: decoded["email"] as? String ?? "user@example.com",
                    profilePictureURL: nil,
                    createdAt: Date().addingTimeInterval(-2592000)
                )
            } else {
                // Fallback to basic authenticated user using available token data
                if let token = mainToken, token.contains("eyJ") {
                    // This looks like a JWT, extract email if possible
                    let email = extractEmailFromToken(token) ?? "user@example.com"
                    let name = email.components(separatedBy: "@").first?.capitalized ?? "Authenticated User"
                    
                    currentUser = AppUser(
                        id: "authenticated",
                        name: name,
                        email: email,
                        profilePictureURL: nil,
                        createdAt: Date().addingTimeInterval(-2592000)
                    )
                } else {
                    currentUser = AppUser(
                        id: "authenticated",
                        name: "Authenticated User", 
                        email: "user@example.com",
                        profilePictureURL: nil,
                        createdAt: Date().addingTimeInterval(-2592000)
                    )
                }
            }
            
            // Always try to load user profile from server (prioritized)
            Task {
                do {
                    print("🔍 Attempting to fetch user profile from SimpleUserManager...")
                    print("🔍 API Base URL: \(Constants.API.baseURL)")
                    await SimpleUserManager.shared.fetchUserProfile()
                    
                    if let profile = SimpleUserManager.shared.userProfile {
                        print("✅ Got user profile from server: \(profile.name ?? "No name") - \(profile.email)")
                        
                        // Update with server data (this should override the JWT fallback data)
                        await MainActor.run {
                            currentUser = AppUser(
                                id: profile.id,
                                name: profile.name ?? "Test User",
                                email: profile.email,
                                profilePictureURL: nil,
                                createdAt: Date().addingTimeInterval(-2592000)
                            )
                        }
                    } else {
                        print("❌ No user profile returned from SimpleUserManager")
                        if let error = SimpleUserManager.shared.error {
                            print("❌ SimpleUserManager error: \(error)")
                        }
                    }
                } catch {
                    print("❌ Failed to load user profile from server: \(error)")
                }
            }
        } else {
            print("❌ Not authenticated - showing guest user")
            // Not authenticated - show guest user
            currentUser = AppUser(
                id: "guest",
                name: "Guest User",
                email: "Not signed in",
                profilePictureURL: nil,
                createdAt: Date()
            )
        }
    }
    
    private func decodeJWT(_ token: String) throws -> [String: Any] {
        let parts = token.components(separatedBy: ".")
        guard parts.count >= 2 else { throw NSError(domain: "JWT", code: 0) }
        
        var base64 = parts[1]
        // Add padding if needed
        while base64.count % 4 != 0 {
            base64 += "="
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "JWT", code: 1)
        }
        
        return json
    }
    
    private func extractEmailFromToken(_ token: String) -> String? {
        guard let decoded = try? decodeJWT(token) else { return nil }
        return decoded["email"] as? String
    }
    
    private func loadUsageData() {
        // Mock usage data
        monthlyCommandsUsed = 45
        monthlyCommandsLimit = 100
    }
    
    private func loadIntegrations() {
        // Mock integrations
        integrations = [
            Integration(id: "google", name: "Google Calendar", iconName: "calendar", color: .blue, isConnected: true),
            Integration(id: "gmail", name: "Gmail", iconName: "envelope", color: .red, isConnected: true),
            Integration(id: "airtable", name: "Airtable", iconName: "table", color: .green, isConnected: false),
            Integration(id: "notion", name: "Notion", iconName: "doc.text", color: .gray, isConnected: false)
        ]
    }
    
    private func loadVoiceSettings() {
        // Load voice settings from UserDefaults
        voiceSettings = VoiceSettings(
            speed: UserDefaults.standard.float(forKey: "voiceSpeed") == 0 ? 1.0 : UserDefaults.standard.float(forKey: "voiceSpeed"),
            pitch: UserDefaults.standard.float(forKey: "voicePitch") == 0 ? 1.0 : UserDefaults.standard.float(forKey: "voicePitch"),
            gender: .female
        )
    }
    
    func updateVoiceSettings(_ settings: VoiceSettings) {
        voiceSettings = settings
        UserDefaults.standard.set(settings.speed, forKey: "voiceSpeed")
        UserDefaults.standard.set(settings.pitch, forKey: "voicePitch")
    }
    
    func toggleIntegration(_ integration: Integration) async {
        // Toggle integration connection
        if let index = integrations.firstIndex(where: { $0.id == integration.id }) {
            integrations[index] = Integration(
                id: integration.id,
                name: integration.name,
                iconName: integration.iconName,
                color: integration.color,
                isConnected: !integration.isConnected
            )
        }
    }
    
    func exportUserData() {
        // Export user data
        print("Exporting user data...")
    }
    
    func deleteAccount() {
        // Delete user account
        print("Deleting account...")
    }
    
    func updatePreferredName(_ newName: String) async {
        isUpdatingPreferences = true
        preferencesUpdateMessage = nil
        
        // Update local state for now (server sync to be implemented)
        preferredName = newName
        UserDefaults.standard.set(newName, forKey: "preferred_name")
        preferencesUpdateMessage = "Preferred name updated successfully"
        
        isUpdatingPreferences = false
        
        // Clear message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.preferencesUpdateMessage = nil
        }
    }
}

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var currentSubscription: Subscription?
    
    func loadSubscription() {
        // Mock subscription data
        currentSubscription = Subscription(
            id: "sub123",
            plan: "Pro",
            isActive: true,
            expiresAt: Date().addingTimeInterval(2592000) // 30 days from now
        )
    }
}

// MARK: - Main View

struct EnhancedSettingsView: View {
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @ObservedObject private var hapticManager = HapticManager.shared
    @ObservedObject private var soundManager = SoundManager.shared
    @ObservedObject private var apiClient = APIClient.shared
    @ObservedObject private var oauthManager = OAuthManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // Optional actions for the settings view
    let onClearHistory: (() -> Void)?
    let onLogout: (() -> Void)?
    
    // Initializer
    init(onClearHistory: (() -> Void)? = nil, onLogout: (() -> Void)? = nil) {
        self.onClearHistory = onClearHistory
        self.onLogout = onLogout
    }
    
    // Hidden debug menu access
    @State private var debugTapCount = 0
    @State private var showDebugMenu = false
    @State private var lastDebugTapTime = Date()
    
    var body: some View {
        NavigationView {
            List {
                // Test Section to see if new sections appear
                Section {
                    HStack {
                        Image(systemName: "link.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 36)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Service Integrations")
                                .font(.headline)
                            
                            Text("Connect Google, Airtable, and more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("Integrations tapped!")
                    }
                } header: {
                    Text("INTEGRATIONS")
                }
                
                // Account Section
                Section {
                    NavigationLink {
                        SimpleUserProfileView()
                    } label: {
                        AccountSummaryRow(user: settingsViewModel.currentUser)
                    }
                    
                    if let subscription = subscriptionManager.currentSubscription {
                        SubscriptionStatusRow(subscription: subscription)
                    } else {
                        UpgradePromptRow()
                    }
                } header: {
                    Text("Account")
                }
                
                // Personalization Section
                PersonalizationSection(viewModel: settingsViewModel)
                
                // Usage Section
                Section {
                    UsageTrackingRow(
                        commandsUsed: settingsViewModel.monthlyCommandsUsed,
                        commandsLimit: settingsViewModel.monthlyCommandsLimit
                    )
                    
                    NavigationLink("Command History") {
                        CommandHistoryView()
                    }
                    
                    NavigationLink("Usage Analytics") {
                        UsageAnalyticsView()
                    }
                } header: {
                    Text("Usage")
                }
                
                
                // Voice Settings
                Section {
                    VoiceSettingsRow(settings: settingsViewModel.voiceSettings) { newSettings in
                        settingsViewModel.updateVoiceSettings(newSettings)
                    }
                    
                    Toggle("Apple Speech Framework", isOn: $settingsViewModel.useAppleSpeech)
                        .onChange(of: settingsViewModel.useAppleSpeech) { oldValue, newValue in
                            hapticManager.settingToggled()
                        }
                    
                    Toggle("Whisper Fallback", isOn: $settingsViewModel.useWhisperFallback)
                        .onChange(of: settingsViewModel.useWhisperFallback) { oldValue, newValue in
                            hapticManager.settingToggled()
                        }
                } header: {
                    Text("Voice Settings")
                }
                
                // Privacy & Security
                Section {
                    NavigationLink("Privacy Controls") {
                        BasicPrivacyControlsView()
                    }
                    
                    NavigationLink("Data Access Log") {
                        DataAccessLogView()
                    }
                    
                    NavigationLink("Security Settings") {
                        SecuritySettingsView()
                    }
                    
                    Button("Export Data") {
                        settingsViewModel.exportUserData()
                    }
                    
                    Button("Delete Account", role: .destructive) {
                        settingsViewModel.showDeleteAccountConfirmation = true
                    }
                } header: {
                    Text("Privacy & Security")
                }
                
                // Accessibility & Interaction
                Section {
                    Toggle("Haptic Feedback", isOn: .constant(true))
                        .onChange(of: true) { oldValue, newValue in
                            hapticManager.settingToggled()
                        }
                    
                    Toggle("Sound Effects", isOn: $soundManager.isSoundEnabled)
                        .onChange(of: soundManager.isSoundEnabled) { oldValue, newValue in
                            hapticManager.settingToggled()
                        }
                    
                    if soundManager.isSoundEnabled {
                        VStack {
                            HStack {
                                Text("Sound Volume")
                                Spacer()
                                Text("\(Int(soundManager.soundVolume * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $soundManager.soundVolume, in: 0...1, step: 0.1)
                                .onChange(of: soundManager.soundVolume) { oldValue, newValue in
                                    soundManager.setSoundVolume(newValue)
                                }
                        }
                    }
                    
                    NavigationLink("Accessibility") {
                        AccessibilitySettingsView()
                    }
                } header: {
                    Text("Accessibility & Interaction")
                }
                
                // Apple Watch Settings
                Section {
                    NavigationLink("Watch Sync") {
                        WatchSyncSettingsView()
                    }
                    
                    NavigationLink("Complications") {
                        ComplicationSettingsView()
                    }
                    
                    NavigationLink("Haptic Patterns") {
                        WatchHapticSettingsView()
                    }
                } header: {
                    Text("Apple Watch")
                }
                
                // Performance & Optimization
                Section {
                    NavigationLink("Performance Monitor") {
                        PerformanceSettingsView()
                    }
                    
                    NavigationLink("Model Optimization") {
                        ModelOptimizationView()
                    }
                    
                    NavigationLink("Battery Impact") {
                        BatteryOptimizationView()
                    }
                    
                    NavigationLink("Batch Processing") {
                        BatchProcessingSettingsView()
                    }
                    
                    NavigationLink("ML & Personalization") {
                        PersonalizationSettingsView()
                    }
                } header: {
                    Text("Performance & Optimization")
                } footer: {
                    Text("Optimize Core ML performance for better battery efficiency and processing speed.")
                }
                
                // Advanced Settings
                Section {
                    NavigationLink("Backend Settings") {
                        BackendSettingsView()
                    }
                    
                    NavigationLink("Developer Options") {
                        DeveloperOptionsView()
                    }
                    
                    NavigationLink("About") {
                        AboutView()
                    }
                } header: {
                    // Hidden debug menu access - tap "Advanced" 7 times within 3 seconds
                    Button(action: handleDebugTap) {
                        HStack {
                            Text("Advanced")
                                .font(.system(.footnote))
                                .textCase(.uppercase)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Additional Actions (if provided)
                if onClearHistory != nil || onLogout != nil {
                    Section {
                        if let onClearHistory = onClearHistory {
                            Button("Clear Chat History", role: .destructive) {
                                onClearHistory()
                            }
                        }
                        
                        if let onLogout = onLogout {
                            Button("Logout", role: .destructive) {
                                onLogout()
                            }
                        }
                    } header: {
                        Text("Actions")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            settingsViewModel.loadSettings()
            subscriptionManager.loadSubscription()
            oauthManager.checkIntegrationStatus()
        }
        .alert("Delete Account", isPresented: $settingsViewModel.showDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                settingsViewModel.deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
        .sheet(isPresented: $showDebugMenu) {
            Text("Debug menu is temporarily disabled")
                .padding()
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Debug Menu Access
    private func handleDebugTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastDebugTapTime)
        
        // Reset counter if more than 3 seconds have passed
        if timeSinceLastTap > 3.0 {
            debugTapCount = 1
        } else {
            debugTapCount += 1
        }
        
        lastDebugTapTime = now
        
        // Provide subtle haptic feedback for each tap
        hapticManager.settingToggled()
        
        // After 5 taps, give stronger feedback
        if debugTapCount == 5 {
            hapticManager.commandSuccess()
        }
        
        // Show debug menu after 7 taps within 3 seconds
        if debugTapCount >= 7 {
            hapticManager.commandSuccess() // Strong success feedback
            showDebugMenu = true
            debugTapCount = 0 // Reset counter
            
            // Add visual feedback by briefly showing an alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🧪 Debug menu activated!")
            }
        }
    }
}

struct AccountSummaryRow: View {
    let user: AppUser?
    
    var body: some View {
        HStack {
            // Profile Picture
            AsyncImage(url: user?.profilePictureURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user?.name ?? "Unknown User")
                    .font(.headline)
                
                Text(user?.email ?? "No email")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Member since \(formatDate(user?.createdAt ?? Date()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct SubscriptionStatusRow: View {
    let subscription: Subscription
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Floe Pro")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("Active until \(formatDate(subscription.expiresAt))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Manage") {
                // Handle subscription management
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct UpgradePromptRow: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Upgrade to Floe Pro")
                    .font(.headline)
                
                Text("Unlimited voice commands, advanced integrations, and more")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Upgrade") {
                // Handle upgrade
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }
}

struct UsageTrackingRow: View {
    let commandsUsed: Int
    let commandsLimit: Int
    
    private var usagePercentage: Double {
        Double(commandsUsed) / Double(commandsLimit)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Monthly Commands")
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(commandsUsed) / \(commandsLimit)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: usagePercentage)
                .tint(usagePercentage > 0.8 ? .orange : .blue)
            
            HStack {
                Text("Reset in \(daysUntilReset()) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if usagePercentage > 0.8 {
                    Text("Approaching limit")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func daysUntilReset() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        return calendar.dateComponents([.day], from: now, to: endOfMonth).day ?? 0
    }
}

struct IntegrationRow: View {
    let integration: Integration
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: integration.iconName)
                .font(.title2)
                .foregroundColor(integration.color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(integration.name)
                    .font(.body)
                
                Text(integration.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(integration.isConnected ? .green : .secondary)
            }
            
            Spacer()
            
            if integration.isConnected {
                Button("Disconnect") {
                    onToggle()
                }
                .buttonStyle(.bordered)
            } else {
                Button("Connect") {
                    onToggle()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }
}

struct VoiceSettingsRow: View {
    let settings: VoiceSettings
    let onUpdate: (VoiceSettings) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Configuration")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Voice Speed")
                    Spacer()
                    Text("\(Int(settings.speed * 100))%")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: .constant(settings.speed), in: 0.5...2.0, step: 0.1)
                    .onChange(of: settings.speed) { oldValue, newValue in
                        var newSettings = settings
                        newSettings.speed = newValue
                        onUpdate(newSettings)
                    }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Voice Pitch")
                    Spacer()
                    Text("\(Int(settings.pitch * 100))%")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: .constant(settings.pitch), in: 0.5...2.0, step: 0.1)
                    .onChange(of: settings.pitch) { oldValue, newValue in
                        var newSettings = settings
                        newSettings.pitch = newValue
                        onUpdate(newSettings)
                    }
            }
            
            Picker("Voice Gender", selection: .constant(settings.gender)) {
                Text("Female").tag(VoiceGender.female)
                Text("Male").tag(VoiceGender.male)
                Text("Neutral").tag(VoiceGender.neutral)
            }
            .pickerStyle(.segmented)
            .onChange(of: settings.gender) { oldValue, newValue in
                var newSettings = settings
                newSettings.gender = newValue
                onUpdate(newSettings)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PersonalizationSection: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var tempPreferredName: String = ""
    @State private var showingNameAlert = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preferred Name")
                            .font(.headline)
                        
                        if viewModel.preferredName.isEmpty {
                            Text("Set how you'd like the assistant to address you")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Currently: \(viewModel.preferredName)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    Button(viewModel.preferredName.isEmpty ? "Set Name" : "Change") {
                        tempPreferredName = viewModel.preferredName
                        showingNameAlert = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isUpdatingPreferences)
                }
                
                if let message = viewModel.preferencesUpdateMessage {
                    HStack {
                        Image(systemName: message.contains("successfully") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(message.contains("successfully") ? .green : .orange)
                        
                        Text(message)
                            .font(.caption)
                            .foregroundColor(message.contains("successfully") ? .green : .orange)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
                
                if viewModel.isUpdatingPreferences {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        
                        Text("Updating preferences...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Personalization")
        } footer: {
            Text("Your preferred name helps the voice assistant provide more personalized responses.")
                .font(.caption)
        }
        .alert("Set Preferred Name", isPresented: $showingNameAlert) {
            TextField("Enter your preferred name", text: $tempPreferredName)
                .focused($isTextFieldFocused)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
            
            Button("Cancel", role: .cancel) {
                tempPreferredName = ""
            }
            
            Button("Save") {
                guard !tempPreferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                
                Task {
                    await viewModel.updatePreferredName(tempPreferredName.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
            .disabled(tempPreferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter the name you'd like the voice assistant to use when addressing you.")
        }
        .onAppear {
            if showingNameAlert {
                isTextFieldFocused = true
            }
        }
    }
}


// MARK: - Supporting Views are in EnhancedSettingsPlaceholderViews.swift

#Preview {
    EnhancedSettingsView()
}