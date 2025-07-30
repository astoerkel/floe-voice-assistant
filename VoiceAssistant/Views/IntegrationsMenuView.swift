import SwiftUI

struct IntegrationsMenuView: View {
    @ObservedObject private var oauthManager = OAuthManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingGoogleServicesDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Integrations")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Connect your services to enhance voice commands")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(UIColor.systemBackground))
                
                // Integration Cards
                ScrollView {
                    VStack(spacing: 16) {
                        // Google Services Card
                        IntegrationMenuCard(
                            title: "Google Services",
                            subtitle: "Calendar, Gmail, Drive, Sheets",
                            icon: "globe",
                            iconColor: .blue,
                            isConnected: oauthManager.isGoogleConnected,
                            integration: oauthManager.getIntegrationsByType("google").first,
                            onTap: {
                                showingGoogleServicesDetail = true
                            }
                        )
                        
                        // Airtable Card
                        IntegrationMenuCard(
                            title: "Airtable",
                            subtitle: "Tasks and project management",
                            icon: "tablecells",
                            iconColor: .green,
                            isConnected: oauthManager.isAirtableConnected,
                            integration: oauthManager.getIntegrationsByType("airtable").first,
                            onTap: {
                                // Navigate to Airtable detail view
                            }
                        )
                        
                        // Coming Soon Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Coming Soon")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 20)
                            
                            // Notion (Coming Soon)
                            IntegrationMenuCard(
                                title: "Notion",
                                subtitle: "Notes and knowledge base",
                                icon: "doc.text",
                                iconColor: Color.secondary,
                                isConnected: false,
                                integration: nil,
                                isEnabled: false,
                                onTap: {}
                            )
                            
                            // Microsoft 365 (Coming Soon)
                            IntegrationMenuCard(
                                title: "Microsoft 365",
                                subtitle: "Outlook, Teams, OneDrive",
                                icon: "square.grid.2x2",
                                iconColor: Color.secondary,
                                isConnected: false,
                                integration: nil,
                                isEnabled: false,
                                onTap: {}
                            )
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingGoogleServicesDetail) {
                GoogleServicesDetailView()
            }
        }
        .onAppear {
            oauthManager.checkIntegrationStatus()
        }
    }
}

struct IntegrationMenuCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let isConnected: Bool
    let integration: OAuthManager.Integration?
    var isEnabled: Bool = true
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(isEnabled ? 0.2 : 0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isEnabled ? iconColor : Color.secondary)
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isEnabled ? .primary : .secondary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if isConnected, let integration = integration {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text("Connected")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            if let email = integration.userInfo?.email {
                                Text("• \(email)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    } else if !isEnabled {
                        Text("Coming soon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Chevron
                if isEnabled {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isConnected ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
    }
}

struct GoogleServicesDetailView: View {
    @ObservedObject private var oauthManager = OAuthManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingDisconnectAlert = false
    @State private var isTestingConnection = false
    @State private var isConnecting = false
    @State private var testResult: String?
    
    var googleIntegration: OAuthManager.Integration? {
        oauthManager.getIntegrationsByType("google").first
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    connectionStatusSection
                    
                    if !oauthManager.isGoogleConnected {
                        connectSection
                    }
                }
                .padding()
            }
            .navigationBarTitle("Google Integration", displayMode: .inline)
            .alert("Disconnect Google", isPresented: $showingDisconnectAlert) {
                disconnectAlert
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "globe")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            Text("Google Services")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Access Calendar, Gmail, Drive, and Sheets with voice commands")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top)
    }
    
    private var connectionStatusSection: some View {
        Group {
            if oauthManager.isGoogleConnected, let integration = googleIntegration {
                connectedStatusView(integration: integration)
            }
        }
    }
    
    private func connectedStatusView(integration: OAuthManager.Integration) -> some View {
        VStack(spacing: 16) {
            // Status Card
            statusCard(integration: integration)
            
            // Permissions
            permissionsCard(integration: integration)
            
            // Actions
            actionsSection
        }
    }
    
    private func statusCard(integration: OAuthManager.Integration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected")
                    .font(.headline)
                    .foregroundColor(.green)
                Spacer()
            }
            
            if let userInfo = integration.userInfo {
                userInfoSection(userInfo: userInfo)
            }
            
            connectionDateSection(integration: integration)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func userInfoSection(userInfo: OAuthManager.Integration.UserInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let email = userInfo.email {
                Label(email, systemImage: "envelope")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let name = userInfo.name {
                Label(name, systemImage: "person")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func connectionDateSection(integration: OAuthManager.Integration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Connected on")
                Text(integration.connectedAt.formatted(date: .abbreviated, time: .shortened))
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            
            if let expiresAt = integration.expiresAt {
                HStack {
                    Text("Token expires")
                    Text(expiresAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }
        }
    }
    
    private func permissionsCard(integration: OAuthManager.Integration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)
            
            ForEach(integration.scope, id: \.self) { scope in
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(formatScope(scope))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            testConnectionButton
            
            if let result = testResult {
                Text(result)
                    .font(.caption)
                    .foregroundColor(result.contains("Success") ? .green : .red)
                    .padding(.horizontal)
            }
            
            disconnectButton
        }
    }
    
    private var testConnectionButton: some View {
        Button(action: testConnection) {
            HStack {
                if isTestingConnection {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "network")
                }
                Text(isTestingConnection ? "Testing..." : "Test Connection")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(Color(UIColor.label))
            .cornerRadius(12)
        }
        .disabled(isTestingConnection)
    }
    
    private var disconnectButton: some View {
        Button(action: { showingDisconnectAlert = true }) {
            HStack {
                Image(systemName: "xmark.circle")
                Text("Disconnect")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .cornerRadius(12)
        }
    }
    
    private var connectSection: some View {
        VStack(spacing: 20) {
            // Features
            VStack(alignment: .leading, spacing: 16) {
                Text("Available Features")
                    .font(.headline)
                
                connectFeaturesList
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            
            // Connect Button
            connectButton
        }
    }
    
    private var connectFeaturesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureRow(icon: "calendar", text: "Schedule and manage calendar events")
            FeatureRow(icon: "envelope", text: "Read and send emails")
            FeatureRow(icon: "folder", text: "Access and organize files in Drive")
            FeatureRow(icon: "doc.text", text: "Create and edit documents")
        }
    }
    
    private var connectButton: some View {
        Button(action: connectToGoogle) {
            HStack {
                if isConnecting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle")
                }
                Text(isConnecting ? "Connecting..." : "Connect to Google")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(Color(UIColor.label))
            .cornerRadius(12)
        }
        .disabled(isConnecting)
    }
    
    private var disconnectAlert: some View {
        Group {
            Button("Disconnect", role: .destructive) {
                disconnectFromGoogle()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - Functions
    
    private func connectToGoogle() {
        isConnecting = true
        
        // Simulate connection process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isConnecting = false
            // In real implementation, this would trigger OAuth flow
            print("Google connection initiated")
        }
    }
    
    private func disconnectFromGoogle() {
        // In real implementation, this would call the OAuth disconnect method
        print("Google disconnection initiated")
    }
    
    private func testConnection() {
        isTestingConnection = true
        testResult = nil
        
        // Simulate test
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isTestingConnection = false
            testResult = "Success: Google API connection verified"
        }
    }
    
    private func formatScope(_ scope: String) -> String {
        // Format Google OAuth scopes for display
        let scopeMap = [
            "https://www.googleapis.com/auth/calendar": "Google Calendar",
            "https://www.googleapis.com/auth/gmail.readonly": "Gmail (Read)",
            "https://www.googleapis.com/auth/gmail.compose": "Gmail (Compose)",
            "https://www.googleapis.com/auth/gmail.send": "Gmail (Send)",
            "https://www.googleapis.com/auth/drive.file": "Google Drive (Files)"
        ]
        
        return scopeMap[scope] ?? scope
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

#Preview {
    IntegrationsMenuView()
        .preferredColorScheme(.dark)
}
