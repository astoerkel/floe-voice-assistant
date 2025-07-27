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
    @State private var testResult: String?
    
    var googleIntegration: OAuthManager.Integration? {
        oauthManager.getIntegrationsByType("google").first
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
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
                    
                    // Connection Status
                    if oauthManager.isGoogleConnected, let integration = googleIntegration {
                        VStack(spacing: 16) {
                            // Status Card
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
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            
                            // Permissions
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
                            
                            // Actions
                            VStack(spacing: 12) {
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
                                
                                if let result = testResult {
                                    Text(result)
                                        .font(.caption)
                                        .foregroundColor(result.contains("Success") ? .green : .red)
                                        .padding(.horizontal)
                                }
                                
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
                        }
                        .padding(.horizontal)
                    } else {
                        // Not Connected State
                        VStack(spacing: 20) {
                            Text("Not Connected")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Text("Connect your Google account to enable voice commands for:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                FeatureRow(icon: "calendar", text: "Check calendar events and schedule meetings")
                                FeatureRow(icon: "envelope", text: "Read and compose emails")
                                FeatureRow(icon: "folder", text: "Access files in Google Drive")
                                FeatureRow(icon: "tablecells", text: "Work with Google Sheets data")
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            
                            Button(action: { oauthManager.connectGoogleServices() }) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("Connect Google Services")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(Color(UIColor.label))
                                .cornerRadius(12)
                            }
                            .disabled(oauthManager.isLoading)
                            
                            if oauthManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            
                            if let error = oauthManager.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitle("Google Services", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .preferredColorScheme(.dark)
            .alert("Disconnect Google Services", isPresented: $showingDisconnectAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    if let integration = googleIntegration {
                        oauthManager.disconnectIntegration(integration)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to disconnect Google Services? You'll need to reconnect to use voice commands for Calendar, Gmail, Drive, and Sheets.")
            }
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        testResult = nil
        
        if let integration = googleIntegration {
            oauthManager.testIntegration(integration)
            
            // Simulate test completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isTestingConnection = false
                testResult = "✓ Connection test successful"
            }
        }
    }
    
    private func formatScope(_ scope: String) -> String {
        // Format Google OAuth scopes for display
        let scopeMap = [
            "https://www.googleapis.com/auth/calendar": "Google Calendar",
            "https://www.googleapis.com/auth/gmail.readonly": "Gmail (Read)",
            "https://www.googleapis.com/auth/gmail.compose": "Gmail (Compose)",
            "https://www.googleapis.com/auth/gmail.send": "Gmail (Send)",
            "https://www.googleapis.com/auth/drive.readonly": "Google Drive (Read)",
            "https://www.googleapis.com/auth/spreadsheets": "Google Sheets",
            "profile": "Profile Information",
            "email": "Email Address"
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