import Foundation
import UIKit

// Simple API Client for the simplified voice assistant backend
public class SimpleAPIClient: ObservableObject {
    public static let shared = SimpleAPIClient()
    
    private let baseURL: String
    private let session: URLSession
    private var accessToken: String?
    private var refreshToken: String?
    private var refreshAttempts: Int = 0
    private let maxRefreshAttempts = 3
    
    @Published var isAuthenticated = false
    @Published var lastError: Error?
    
    init(baseURL: String = Constants.API.baseURL) {
        print("🚀 SimpleAPIClient: Initializing with baseURL: \(baseURL)")
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.API.requestTimeout
        config.timeoutIntervalForResource = Constants.API.requestTimeout
        self.session = URLSession(configuration: config)
        
        // Load stored tokens
        loadTokens()
        
        // Sync tokens with APIClient immediately if we have them
        if isAuthenticated {
            print("🔑 SimpleAPIClient: Found existing token, syncing with APIClient...")
            DispatchQueue.main.async {
                APIClient.shared.syncTokensFromSimpleAPIClient()
            }
            print("🔑 SimpleAPIClient: Validating token...")
            validateToken()
        } else {
            print("🔑 SimpleAPIClient: No existing token found")
        }
        
        // Test basic connectivity
        testConnectivity()
    }
    
    private func loadTokens() {
        self.accessToken = UserDefaults.standard.string(forKey: Constants.StorageKeys.accessToken)
        self.refreshToken = UserDefaults.standard.string(forKey: Constants.StorageKeys.refreshToken)
        
        // For debugging - print token prefix
        if let token = accessToken {
            print("🔑 Token found: \(String(token.prefix(20)))...")
            
            // Check if it's an old development token and clear it
            if token.contains("mock") || token.contains("development") {
                print("🔑 Clearing old development token")
                clearTokens()
                return
            }
        }
        
        self.isAuthenticated = (accessToken != nil)
        print("🔑 Token loaded. Authenticated: \(isAuthenticated)")
    }
    
    // MARK: - Authentication
    func authenticateWithApple(idToken: String, user: [String: Any]?, completion: @escaping (Result<Bool, Error>) -> Void) {
        print("🍎 SimpleAPIClient: Starting Apple authentication")
        print("🍎 SimpleAPIClient: Using URL: \(Constants.API.appleSignInURL)")
        
        guard let url = URL(string: Constants.API.appleSignInURL) else {
            print("❌ SimpleAPIClient: Invalid URL: \(Constants.API.appleSignInURL)")
            completion(.failure(VoiceAssistantError.networkError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "idToken": idToken,
            "user": user ?? [:]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
            
            // Debug: Log the JSON being sent
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🌐 SimpleAPIClient: Sending JSON: \(jsonString)")
            }
        } catch {
            print("❌ SimpleAPIClient: JSON serialization failed: \(error)")
            completion(.failure(error))
            return
        }
        
        print("🌐 SimpleAPIClient: Making request to \(url)")
        print("🌐 SimpleAPIClient: Request timeout: \(Constants.API.requestTimeout)s")
        print("🌐 SimpleAPIClient: Request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("🌐 SimpleAPIClient: Request body size: \(request.httpBody?.count ?? 0) bytes")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            print("🔍 SimpleAPIClient: URLSession completion handler called")
            print("🔍 SimpleAPIClient: Error: \(String(describing: error))")
            print("🔍 SimpleAPIClient: Response: \(String(describing: response))")
            print("🔍 SimpleAPIClient: Data size: \(data?.count ?? 0) bytes")
            
            // Log response data for debugging
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("🔍 SimpleAPIClient: Response data: \(responseString)")
            }
            if let error = error {
                print("❌ SimpleAPIClient: Network error: \(error)")
                print("❌ SimpleAPIClient: Error domain: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("❌ SimpleAPIClient: Error code: \(nsError.code)")
                    print("❌ SimpleAPIClient: Error domain: \(nsError.domain)")
                }
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.networkError))
                }
                return
            }
            
            // Handle different HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    // Parse simple backend response format
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = jsonResponse["success"] as? Bool,
                       success,
                       let token = jsonResponse["accessToken"] as? String {
                        // Store the JWT token from simple backend
                        self?.setAuthToken(token)
                        
                        // Store refresh token if available
                        if let refreshToken = jsonResponse["refreshToken"] as? String {
                            self?.setRefreshToken(refreshToken)
                        }
                        
                        // Store user information if available
                        if let userInfo = jsonResponse["user"] as? [String: Any] {
                            self?.storeUserInfo(userInfo)
                        } else if let userInfo = user {
                            // Use the user info from Apple Sign In
                            self?.storeUserInfo(userInfo)
                        }
                        
                        DispatchQueue.main.async {
                            completion(.success(true))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(VoiceAssistantError.authenticationFailed))
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            case 400:
                // Handle Apple authentication errors (Invalid token, etc.)
                print("❌ SimpleAPIClient: Apple auth failed - HTTP 400")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ SimpleAPIClient: Error response: \(errorString)")
                }
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.authenticationFailed))
                }
            case 401:
                print("🚨 SimpleAPIClient: 401 Unauthorized - Apple auth failed")
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.authenticationFailed))
                }
            case 500...599:
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.serverError(httpResponse.statusCode)))
                }
            default:
                print("❌ SimpleAPIClient: Unexpected status code: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.serverError(httpResponse.statusCode)))
                }
            }
        }.resume()
    }
    
    // MARK: - Email Authentication
    func registerWithEmail(email: String, password: String, name: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        print("📧 SimpleAPIClient: Starting email registration")
        print("📧 SimpleAPIClient: Using URL: \(Constants.API.registerURL)")
        
        guard let url = URL(string: Constants.API.registerURL) else {
            print("❌ SimpleAPIClient: Invalid registration URL: \(Constants.API.registerURL)")
            completion(.failure(VoiceAssistantError.networkError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "password": password,
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        
        performAuthRequest(request: request, body: body, completion: completion)
    }
    
    func loginWithEmail(email: String, password: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        print("📧 SimpleAPIClient: Starting email login")
        print("📧 SimpleAPIClient: Using URL: \(Constants.API.loginURL)")
        
        guard let url = URL(string: Constants.API.loginURL) else {
            print("❌ SimpleAPIClient: Invalid login URL: \(Constants.API.loginURL)")
            completion(.failure(VoiceAssistantError.networkError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "password": password
        ]
        
        performAuthRequest(request: request, body: body, completion: completion)
    }
    
    // MARK: - Google Authentication (placeholder)
    func authenticateWithGoogle(idToken: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        print("🔍 SimpleAPIClient: Starting Google authentication")
        print("🔍 SimpleAPIClient: Using URL: \(Constants.API.googleSignInURL)")
        
        guard let url = URL(string: Constants.API.googleSignInURL) else {
            print("❌ SimpleAPIClient: Invalid Google sign-in URL: \(Constants.API.googleSignInURL)")
            completion(.failure(VoiceAssistantError.networkError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "idToken": idToken
        ]
        
        performAuthRequest(request: request, body: body, completion: completion)
    }
    
    // MARK: - Shared Authentication Request Handler
    private func performAuthRequest(request: URLRequest, body: [String: Any], completion: @escaping (Result<Bool, Error>) -> Void) {
        var request = request
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
            
            // Debug: Log the JSON being sent
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🌐 SimpleAPIClient: Sending JSON: \(jsonString)")
            }
        } catch {
            print("❌ SimpleAPIClient: JSON serialization failed: \(error)")
            completion(.failure(error))
            return
        }
        
        print("🌐 SimpleAPIClient: Making request to \(request.url?.absoluteString ?? "unknown")")
        print("🌐 SimpleAPIClient: Request timeout: \(Constants.API.requestTimeout)s")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            print("🔍 SimpleAPIClient: URLSession completion handler called")
            
            if let error = error {
                print("❌ SimpleAPIClient: Network error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.networkError))
                }
                return
            }
            
            // Log response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔍 SimpleAPIClient: Response (\(httpResponse.statusCode)): \(responseString)")
            }
            
            // Handle different HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    // Parse backend response format
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = jsonResponse["success"] as? Bool,
                       success,
                       let token = jsonResponse["accessToken"] as? String {
                        // Store the JWT token
                        self?.setAuthToken(token)
                        
                        // Store user information if available
                        if let userInfo = jsonResponse["user"] as? [String: Any] {
                            self?.storeUserInfo(userInfo)
                        }
                        
                        DispatchQueue.main.async {
                            completion(.success(true))
                        }
                    } else {
                        // Handle error response
                        if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorMessage = jsonResponse["error"] as? String {
                            print("❌ SimpleAPIClient: Server error: \(errorMessage)")
                        }
                        DispatchQueue.main.async {
                            completion(.failure(VoiceAssistantError.authenticationFailed))
                        }
                    }
                } catch {
                    print("❌ SimpleAPIClient: JSON parsing failed: \(error)")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            case 400:
                // Handle validation errors
                print("❌ SimpleAPIClient: Authentication failed - HTTP 400")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ SimpleAPIClient: Error response: \(errorString)")
                }
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.authenticationFailed))
                }
            case 401:
                print("🚨 SimpleAPIClient: 401 Unauthorized - Authentication failed")
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.authenticationFailed))
                }
            case 500...599:
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.serverError(httpResponse.statusCode)))
                }
            default:
                print("❌ SimpleAPIClient: Unexpected status code: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.serverError(httpResponse.statusCode)))
                }
            }
        }.resume()
    }
    
    func refreshAuthenticationStatus() {
        loadTokens()
    }
    
    private func validateToken() {
        guard let accessToken = accessToken else {
            clearTokens()
            return
        }
        
        // Use the profile endpoint to validate token since verify endpoint doesn't exist
        guard let url = URL(string: "\(Constants.API.baseURL)/api/auth/profile") else {
            // Don't clear tokens if URL is invalid
            print("⚠️ Invalid validation URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Constants.API.apiKey, forHTTPHeaderField: "x-api-key")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        print("🔑 Token validation successful")
                        // Sync with APIClient after successful validation
                        APIClient.shared.syncTokensFromSimpleAPIClient()
                    case 401:
                        print("🔑 Token expired or invalid, clearing tokens")
                        self?.clearTokens()
                    default:
                        // Don't clear tokens for other errors (network, server issues, etc)
                        print("⚠️ Token validation request failed with status: \(httpResponse.statusCode)")
                    }
                } else {
                    // Network error - don't clear tokens
                    print("⚠️ Token validation network error: \(error?.localizedDescription ?? "Unknown")")
                }
            }
        }.resume()
    }
    
    private func setAuthToken(_ token: String) {
        self.accessToken = token
        UserDefaults.standard.set(token, forKey: Constants.StorageKeys.accessToken)
        DispatchQueue.main.async {
            self.isAuthenticated = true
            // Sync token with APIClient
            APIClient.shared.syncTokensFromSimpleAPIClient()
        }
        print("✅ Authentication token stored successfully")
    }
    
    private func setRefreshToken(_ token: String) {
        self.refreshToken = token
        UserDefaults.standard.set(token, forKey: Constants.StorageKeys.refreshToken)
        print("✅ Refresh token stored successfully")
    }
    
    // MARK: - Token Access
    var currentAccessToken: String? {
        return accessToken
    }
    
    // MARK: - Token Refresh
    private func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = refreshToken else {
            print("❌ SimpleAPIClient: No refresh token available")
            completion(false)
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/auth/refresh") else {
            print("❌ SimpleAPIClient: Invalid refresh URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["refreshToken": refreshToken]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ SimpleAPIClient: Failed to encode refresh request: \(error)")
            completion(false)
            return
        }
        
        print("🔄 SimpleAPIClient: Attempting token refresh...")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ SimpleAPIClient: Refresh request failed: \(error)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                print("❌ SimpleAPIClient: Invalid refresh response")
                completion(false)
                return
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let newAccessToken = jsonResponse["accessToken"] as? String {
                        self?.setAuthToken(newAccessToken)
                        
                        // Update refresh token if provided
                        if let newRefreshToken = jsonResponse["refreshToken"] as? String {
                            self?.setRefreshToken(newRefreshToken)
                        }
                        
                        print("✅ SimpleAPIClient: Token refreshed successfully")
                        completion(true)
                    } else {
                        print("❌ SimpleAPIClient: Invalid refresh response format")
                        completion(false)
                    }
                } catch {
                    print("❌ SimpleAPIClient: Failed to parse refresh response: \(error)")
                    completion(false)
                }
            } else {
                print("❌ SimpleAPIClient: Token refresh failed with status: \(httpResponse.statusCode)")
                // If refresh fails, clear all tokens
                self?.clearTokens()
                completion(false)
            }
        }.resume()
    }
    
    // MARK: - Voice Processing
    func processTextSimple(text: String, completion: @escaping (Result<VoiceResponse, Error>) -> Void) {
        guard isAuthenticated else {
            completion(.failure(VoiceAssistantError.authenticationRequired))
            return
        }
        
        guard let url = URL(string: Constants.API.chatProcessURL) else {
            completion(.failure(VoiceAssistantError.networkError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.API.apiKey, forHTTPHeaderField: "x-api-key")
        
        if let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("🔑 SimpleAPIClient: Using auth token: \(accessToken.prefix(20))...")
        } else {
            print("❌ SimpleAPIClient: No access token available for request")
        }
        
        print("📤 SimpleAPIClient: Making request to \(url)")
        print("📤 SimpleAPIClient: Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let body: [String: Any] = [
            "text": text,
            "sessionId": Constants.getCurrentSessionId(),
            "context": [
                "platform": "iOS",
                "deviceModel": "iPhone"
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.networkError))
                }
                return
            }
            
            // Handle different HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = jsonResponse["success"] as? Bool,
                       success,
                       let text = jsonResponse["text"] as? String {
                        
                        let audioBase64 = jsonResponse["audioBase64"] as? String
                        let voiceResponse = VoiceResponse(
                            text: text,
                            success: true,
                            audioBase64: audioBase64
                        )
                        
                        DispatchQueue.main.async {
                            completion(.success(voiceResponse))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(VoiceAssistantError.invalidResponse))
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            case 401:
                print("🚨 SimpleAPIClient: 401 Unauthorized - Attempting token refresh")
                print("📡 401 Response headers: \(httpResponse.allHeaderFields)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📡 401 Response body: \(responseString)")
                }
                
                // Attempt token refresh before giving up
                self.refreshAccessToken { refreshSuccess in
                    if refreshSuccess {
                        print("✅ SimpleAPIClient: Token refresh successful, retrying request")
                        // Retry the original request with new token
                        self.processTextSimple(text: text, completion: completion)
                    } else {
                        print("❌ SimpleAPIClient: Token refresh failed, clearing tokens")
                        DispatchQueue.main.async {
                            self.clearTokens()
                            completion(.failure(VoiceAssistantError.authenticationRequired))
                        }
                    }
                }
            case 500...599:
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.serverError(httpResponse.statusCode)))
                }
            default:
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.serverError(httpResponse.statusCode)))
                }
            }
        }.resume()
    }
    
    // MARK: - Network Testing
    private func testConnectivity() {
        guard let url = URL(string: Constants.API.healthURL) else {
            print("❌ testConnectivity: Invalid health URL")
            return
        }
        
        print("🌐 testConnectivity: Testing connection to \(url)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ testConnectivity: Failed - \(error)")
                if let nsError = error as NSError? {
                    print("❌ testConnectivity: Error domain: \(nsError.domain), code: \(nsError.code)")
                }
            } else if let httpResponse = response as? HTTPURLResponse {
                print("✅ testConnectivity: Success - HTTP \(httpResponse.statusCode)")
            } else {
                print("❌ testConnectivity: Unknown response type")
            }
        }.resume()
    }
    
    // MARK: - Logout
    func logout(completion: @escaping (Result<Bool, Error>) -> Void) {
        clearTokens()
        DispatchQueue.main.async {
            completion(.success(true))
        }
    }
    
    // Force logout for debugging/testing
    func forceLogout() {
        clearTokens()
        print("🔑 Forced logout completed")
    }
    
    // MARK: - User Info
    func getCurrentUserInfo() -> (email: String?, name: String?) {
        let defaults = UserDefaults.standard
        let email = defaults.string(forKey: "cached_user_email")
        let name = defaults.string(forKey: "cached_user_name")
        return (email, name)
    }
    
    private func clearTokens() {
        self.accessToken = nil
        self.refreshToken = nil
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.accessToken)
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.refreshToken)
        
        // Also clear cached user info
        UserDefaults.standard.removeObject(forKey: "cached_user_email")
        UserDefaults.standard.removeObject(forKey: "cached_user_name")
        
        DispatchQueue.main.async {
            self.isAuthenticated = false
        }
        print("🔑 Authentication tokens cleared")
    }
    
    private func storeUserInfo(_ userInfo: [String: Any]) {
        let defaults = UserDefaults.standard
        
        // Store email if available
        if let email = userInfo["email"] as? String {
            defaults.set(email, forKey: "cached_user_email")
        }
        
        // Store name if available
        if let name = userInfo["name"] as? String {
            defaults.set(name, forKey: "cached_user_name")
        } else if let givenName = userInfo["givenName"] as? String,
                  let familyName = userInfo["familyName"] as? String {
            let fullName = "\(givenName) \(familyName)"
            defaults.set(fullName, forKey: "cached_user_name")
        }
        
        defaults.synchronize()
        print("✅ User info cached successfully")
    }
}