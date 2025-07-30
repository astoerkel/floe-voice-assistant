import Foundation
import UIKit

extension Notification.Name {
    static let oauthStatusChanged = Notification.Name("oauthStatusChanged")
}

@MainActor
class OAuthManager: ObservableObject {
    static let shared = OAuthManager()
    
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
        
        // Custom date decoding to handle string dates from backend
        enum CodingKeys: String, CodingKey {
            case id, type, isActive, lastSyncAt, connectedAt, scope, expiresAt, userInfo
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            id = try container.decode(String.self, forKey: .id)
            type = try container.decode(String.self, forKey: .type)
            isActive = try container.decode(Bool.self, forKey: .isActive)
            scope = try container.decode([String].self, forKey: .scope)
            userInfo = try container.decodeIfPresent(UserInfo.self, forKey: .userInfo)
            
            // Handle date fields that might be strings or nil
            let dateFormatter = ISO8601DateFormatter()
            
            if let lastSyncString = try container.decodeIfPresent(String.self, forKey: .lastSyncAt) {
                lastSyncAt = dateFormatter.date(from: lastSyncString)
            } else {
                lastSyncAt = nil
            }
            
            if let connectedAtString = try container.decodeIfPresent(String.self, forKey: .connectedAt) {
                connectedAt = dateFormatter.date(from: connectedAtString) ?? Date()
            } else {
                connectedAt = Date()
            }
            
            if let expiresAtString = try container.decodeIfPresent(String.self, forKey: .expiresAt) {
                expiresAt = dateFormatter.date(from: expiresAtString)
            } else {
                expiresAt = nil
            }
        }
    }
    
    private init() {
        checkIntegrationStatus()
        
        // Listen for OAuth status changes
        NotificationCenter.default.addObserver(
            forName: .oauthStatusChanged,
            object: nil,
            queue: .main
        ) { _ in
            self.checkIntegrationStatus()
        }
    }
    
    func connectGoogleServices() {
        print("🔵 OAuthManager: Starting Google OAuth flow")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Generate a unique device ID for this OAuth session
                let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                print("🔵 OAuthManager: Device ID: \(deviceId)")
                
                // Use public OAuth endpoint that doesn't require authentication
                let body: [String: Any] = [
                    "returnUrl": "voiceassistant://oauth",
                    "deviceId": deviceId
                ]
                
                print("🔵 OAuthManager: Calling /api/oauth/public/google/init")
                let response = try await apiClient.post("/api/oauth/public/google/init", body: body)
                print("🔵 OAuthManager: Response received: \(response)")
                
                if let authUrl = response["authUrl"] as? String {
                    print("🔵 OAuthManager: Auth URL received: \(authUrl)")
                    await openAuthURL(authUrl)
                } else {
                    print("❌ OAuthManager: No authUrl in response")
                    errorMessage = "Failed to get authorization URL"
                }
            } catch {
                print("❌ OAuthManager: Error: \(error)")
                errorMessage = "Failed to start Google OAuth. \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    func connectAirtableServices() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Generate a unique device ID for this OAuth session
                let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                
                // Use public OAuth endpoint that doesn't require authentication
                let body: [String: Any] = [
                    "returnUrl": "voiceassistant://oauth",
                    "deviceId": deviceId
                ]
                
                let response = try await apiClient.post("/api/oauth/public/airtable/init", body: body)
                
                if let authUrl = response["authUrl"] as? String {
                    await openAuthURL(authUrl)
                } else {
                    errorMessage = "Failed to get authorization URL"
                }
            } catch {
                errorMessage = "Failed to start Airtable OAuth. \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func openAuthURL(_ urlString: String) async {
        print("🔵 OAuthManager: Attempting to open URL: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("❌ OAuthManager: Invalid URL")
            errorMessage = "Invalid authorization URL"
            return
        }
        
        await MainActor.run {
            if UIApplication.shared.canOpenURL(url) {
                print("🔵 OAuthManager: Opening URL in browser")
                UIApplication.shared.open(url) { success in
                    print("🔵 OAuthManager: URL open result: \(success)")
                }
            } else {
                print("❌ OAuthManager: Cannot open URL")
                errorMessage = "Cannot open authorization URL"
            }
        }
    }
    
    func checkIntegrationStatus() {
        Task {
            await checkIntegrationStatusAsync()
        }
    }
    
    func checkIntegrationStatusAsync() async {
        do {
            print("🔄 OAuthManager: Checking integration status from backend...")
            let response = try await apiClient.get("/api/oauth/integrations")
            
            if let integrationsData = response["integrations"] as? [[String: Any]] {
                print("📊 OAuthManager: Received \(integrationsData.count) integrations from backend")
                
                integrations = try integrationsData.compactMap { data in
                    let jsonData = try JSONSerialization.data(withJSONObject: data)
                    return try JSONDecoder().decode(Integration.self, from: jsonData)
                }
                
                let wasGoogleConnected = isGoogleConnected
                let wasAirtableConnected = isAirtableConnected
                
                isGoogleConnected = integrations.contains { $0.type == "google" && $0.isActive }
                isAirtableConnected = integrations.contains { $0.type == "airtable" && $0.isActive }
                
                print("✅ OAuthManager: Google connected: \(isGoogleConnected) (was: \(wasGoogleConnected))")
                print("✅ OAuthManager: Airtable connected: \(isAirtableConnected) (was: \(wasAirtableConnected))")
                
                // Debug: Print full integration details
                for integration in integrations {
                    print("   - \(integration.type): active=\(integration.isActive), email=\(integration.userInfo?.email ?? "N/A")")
                }
            } else {
                print("⚠️ OAuthManager: No integrations data received from backend")
            }
        } catch {
            print("❌ OAuthManager: Failed to check integration status: \(error)")
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