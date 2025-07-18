//
//  EnhancedSettingsView.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import SwiftUI

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
    
    func loadSettings() {
        // Load user settings
        loadUserData()
        loadUsageData()
        loadIntegrations()
        loadVoiceSettings()
    }
    
    private func loadUserData() {
        // Mock user data
        currentUser = AppUser(
            id: "user123",
            name: "John Doe",
            email: "john@example.com",
            profilePictureURL: nil,
            createdAt: Date().addingTimeInterval(-2592000) // 30 days ago
        )
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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section {
                    AccountSummaryRow(user: settingsViewModel.currentUser)
                    
                    if let subscription = subscriptionManager.currentSubscription {
                        SubscriptionStatusRow(subscription: subscription)
                    } else {
                        UpgradePromptRow()
                    }
                } header: {
                    Text("Account")
                }
                
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
                
                // Connected Services
                Section(header: Text("Connected Services")) {
                    NavigationLink("Service Integrations") {
                        OAuthIntegrationsView()
                    }
                    
                    NavigationLink("Legacy Setup") {
                        IntegrationsSetupView(apiClient: apiClient, onComplete: {})
                    }
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
                        PrivacyControlsView()
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
                    Text("Advanced")
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
        }
        .alert("Delete Account", isPresented: $settingsViewModel.showDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                settingsViewModel.deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
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
                Text("Sora Pro")
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
                Text("Upgrade to Sora Pro")
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

// MARK: - Supporting Views are in EnhancedSettingsPlaceholderViews.swift

#Preview {
    EnhancedSettingsView()
}