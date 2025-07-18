import Foundation
import UIKit

@MainActor
class OAuthManager: ObservableObject {
    @Published var isGoogleConnected = false
    @Published var isAirtableConnected = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var integrations: [Integration] = []
    
    private let apiClient = APIClient.shared
    
    struct Integration: Identifiable, Codable {
        let id: String
        let type: String
        let isActive: Bool
        let lastSyncAt: Date?
        let connectedAt: Date
        let scope: [String]
        let expiresAt: Date?
        let userInfo: UserInfo?
        
        struct UserInfo: Codable {
            let email: String?
            let name: String?
            let picture: String?
        }
    }
    
    init() {
        checkIntegrationStatus()
    }
    
    func connectGoogleServices() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await apiClient.get("/api/oauth/google/init")
                
                if let authUrl = response["authUrl"] as? String {
                    await openAuthURL(authUrl)
                } else {
                    errorMessage = "Failed to get authorization URL"
                }
            } catch {
                errorMessage = "Failed to start Google OAuth: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    func connectAirtableServices() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await apiClient.get("/api/oauth/airtable/init")
                
                if let authUrl = response["authUrl"] as? String {
                    await openAuthURL(authUrl)
                } else {
                    errorMessage = "Failed to get authorization URL"
                }
            } catch {
                errorMessage = "Failed to start Airtable OAuth: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func openAuthURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid authorization URL"
            return
        }
        
        if await UIApplication.shared.canOpenURL(url) {
            await UIApplication.shared.open(url)
        } else {
            errorMessage = "Cannot open authorization URL"
        }
    }
    
    func checkIntegrationStatus() {
        Task {
            do {
                let response = try await apiClient.get("/api/oauth/integrations")
                
                if let integrationsData = response["integrations"] as? [[String: Any]] {
                    integrations = try integrationsData.compactMap { data in
                        let jsonData = try JSONSerialization.data(withJSONObject: data)
                        return try JSONDecoder().decode(Integration.self, from: jsonData)
                    }
                    
                    isGoogleConnected = integrations.contains { $0.type == "google" && $0.isActive }
                    isAirtableConnected = integrations.contains { $0.type == "airtable" && $0.isActive }
                }
            } catch {
                print("Failed to check integration status: \(error)")
            }
        }
    }
    
    func disconnectIntegration(_ integration: Integration) {
        Task {
            do {
                let _ = try await apiClient.delete("/api/oauth/integrations/\(integration.id)")
                
                // Remove from local state
                integrations.removeAll { $0.id == integration.id }
                
                // Update connection flags
                isGoogleConnected = integrations.contains { $0.type == "google" && $0.isActive }
                isAirtableConnected = integrations.contains { $0.type == "airtable" && $0.isActive }
                
            } catch {
                errorMessage = "Failed to disconnect integration: \(error.localizedDescription)"
            }
        }
    }
    
    func testIntegration(_ integration: Integration) {
        Task {
            do {
                let response = try await apiClient.get("/api/oauth/integrations/\(integration.type)/test")
                
                if let success = response["success"] as? Bool, success {
                    print("Integration test successful for \(integration.type)")
                } else {
                    errorMessage = "Integration test failed for \(integration.type)"
                }
            } catch {
                errorMessage = "Failed to test integration: \(error.localizedDescription)"
            }
        }
    }
    
    func refreshIntegrations() {
        checkIntegrationStatus()
    }
}

extension OAuthManager {
    func getIntegrationsByType(_ type: String) -> [Integration] {
        return integrations.filter { $0.type == type }
    }
    
    func isIntegrationActive(_ type: String) -> Bool {
        return integrations.contains { $0.type == type && $0.isActive }
    }
    
    func getIntegrationExpiryDate(_ type: String) -> Date? {
        return integrations.first { $0.type == type }?.expiresAt
    }
}