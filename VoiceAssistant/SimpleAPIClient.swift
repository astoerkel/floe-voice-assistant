import Foundation
import UIKit

// Simple API Client for the simplified voice assistant backend
public class SimpleAPIClient: ObservableObject {
    public static let shared = SimpleAPIClient()
    
    private let baseURL: String
    private let session: URLSession
    private var accessToken: String?
    
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
        
        // Validate token if present  
        if isAuthenticated {
            print("🔑 SimpleAPIClient: Found existing token, validating...")
            validateToken()
        } else {
            print("🔑 SimpleAPIClient: No existing token found")
        }
        
        // Test basic connectivity
        testConnectivity()
    }
    
    private func loadTokens() {
        self.accessToken = UserDefaults.standard.string(forKey: Constants.StorageKeys.accessToken)
        
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
        
        // Test the token with a simple request
        guard let url = URL(string: Constants.API.verifyTokenURL) else {
            clearTokens()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    print("🔑 Token validation successful")
                } else {
                    print("🔑 Token validation failed, clearing tokens")
                    self?.clearTokens()
                }
            }
        }.resume()
    }
    
    private func setAuthToken(_ token: String) {
        self.accessToken = token
        UserDefaults.standard.set(token, forKey: Constants.StorageKeys.accessToken)
        DispatchQueue.main.async {
            self.isAuthenticated = true
        }
        print("✅ Authentication token stored successfully")
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
        
        if let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = ["text": text]
        
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
                print("🚨 SimpleAPIClient: 401 Unauthorized - Auto-clearing tokens")
                DispatchQueue.main.async {
                    // Automatically clear invalid tokens
                    self.clearTokens()
                    completion(.failure(VoiceAssistantError.authenticationRequired))
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
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.accessToken)
        
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