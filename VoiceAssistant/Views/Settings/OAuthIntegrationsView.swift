import SwiftUI

struct OAuthIntegrationsView: View {
    @ObservedObject private var oauthManager = OAuthManager.shared
    @State private var showingDisconnectAlert = false
    @State private var integrationToDisconnect: OAuthManager.Integration?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Service Integrations")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Connect your favorite services to unlock powerful voice commands")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    
                    // Google Services
                    integrationCard(
                        title: "Google Services",
                        subtitle: "Calendar, Gmail, Drive, Sheets",
                        icon: "globe",
                        isConnected: oauthManager.isGoogleConnected,
                        integration: oauthManager.getIntegrationsByType("google").first
                    ) {
                        oauthManager.connectGoogleServices()
                    }
                    
                    // Airtable
                    integrationCard(
                        title: "Airtable",
                        subtitle: "Task and project management",
                        icon: "tablecells",
                        isConnected: oauthManager.isAirtableConnected,
                        integration: oauthManager.getIntegrationsByType("airtable").first
                    ) {
                        oauthManager.connectAirtableServices()
                    }
                    
                    // Error message
                    if let errorMessage = oauthManager.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("Error")
                                    .fontWeight(.medium)
                            }
                            
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Integrations")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                oauthManager.refreshIntegrations()
            }
            .alert("Disconnect Integration", isPresented: $showingDisconnectAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    if let integration = integrationToDisconnect {
                        oauthManager.disconnectIntegration(integration)
                    }
                }
            } message: {
                Text("Are you sure you want to disconnect this integration? You'll need to reconnect to use voice commands for this service.")
            }
        }
    }
    
    @ViewBuilder
    private func integrationCard(
        title: String,
        subtitle: String,
        icon: String,
        isConnected: Bool,
        integration: OAuthManager.Integration?,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            
            if let integration = integration {
                VStack(alignment: .leading, spacing: 8) {
                    if let userInfo = integration.userInfo {
                        HStack {
                            Text("Connected as:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(userInfo.name ?? userInfo.email ?? "Unknown")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    
                    HStack {
                        Text("Connected: \(integration.connectedAt.formatted(.dateTime.month().day().year()))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let expiresAt = integration.expiresAt {
                            Text("Expires: \(expiresAt.formatted(.dateTime.month().day().year()))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            HStack {
                if isConnected {
                    Button("Test Connection") {
                        if let integration = integration {
                            oauthManager.testIntegration(integration)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    
                    Spacer()
                    
                    Button("Disconnect") {
                        integrationToDisconnect = integration
                        showingDisconnectAlert = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button("Connect") {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(oauthManager.isLoading)
                    
                    Spacer()
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

#Preview {
    OAuthIntegrationsView()
}