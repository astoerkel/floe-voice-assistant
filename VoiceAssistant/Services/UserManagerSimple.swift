//
//  UserManagerSimple.swift
//  VoiceAssistant
//
//  Created by Claude on 26.07.25.
//

import Foundation

// MARK: - Simple User Data Models

struct SimpleUserProfile: Codable {
    let id: String
    let email: String
    let name: String?
    let subscriptionTier: String
    let subscriptionStatus: String
    let monthlyUsageCount: Int
    let monthlyUsageLimit: Int
    let isActive: Bool
}

struct SimpleUserProfileResponse: Codable {
    let success: Bool
    let user: SimpleUserProfile
}

// MARK: - Simple User Manager Service

@MainActor
class SimpleUserManager: ObservableObject {
    static let shared = SimpleUserManager()
    
    @Published var userProfile: SimpleUserProfile?
    @Published var isLoading = false
    @Published var error: String?
    
    private let apiClient = APIClient.shared
    private var baseURL: String { Constants.API.baseURL }
    private var apiKey: String { Constants.API.apiKey }
    
    private init() {}
    
    // MARK: - User Profile Management
    
    func fetchUserProfile() async {
        guard apiClient.isAuthenticated else {
            self.error = "User not authenticated"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            guard let url = URL(string: "\(baseURL)/api/user/profile") else {
                throw SimpleUserManagerError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Add access token if available
            if let token = UserDefaults.standard.string(forKey: "voice_assistant_access_token") {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SimpleUserManagerError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let profileResponse = try decoder.decode(SimpleUserProfileResponse.self, from: data)
                self.userProfile = profileResponse.user
                print("✅ SimpleUserManager: Profile loaded successfully for user: \(profileResponse.user.email)")
            } else {
                print("❌ SimpleUserManager: Server returned status \(httpResponse.statusCode)")
                if let responseText = String(data: data, encoding: .utf8) {
                    print("❌ SimpleUserManager: Response body: \(responseText)")
                }
                throw SimpleUserManagerError.serverError(httpResponse.statusCode)
            }
        } catch {
            self.error = "Failed to fetch user profile: \(error.localizedDescription)"
            print("❌ SimpleUserManager: Failed to fetch profile - \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Utility Methods
    
    func clearUserData() {
        userProfile = nil
        error = nil
    }
    
    // MARK: - JWT Helper Methods
    
    private func decodeJWTPayload(token: String) -> [String: Any]? {
        let segments = token.components(separatedBy: ".")
        guard segments.count == 3 else { return nil }
        
        let payload = segments[1]
        var base64 = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        while base64.count % 4 != 0 {
            base64 += "="
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }
        
        return json
    }
}

// MARK: - Error Types

enum SimpleUserManagerError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError:
            return "Network error"
        }
    }
}