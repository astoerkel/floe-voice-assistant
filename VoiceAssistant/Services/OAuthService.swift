//
//  OAuthService.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import Foundation
import AuthenticationServices
import SafariServices

@MainActor
class OAuthService: NSObject, ObservableObject {
    static let shared = OAuthService()
    
    @Published var isLoading = false
    @Published var connectedServices: [String: ConnectedServiceInfo] = [:]
    
    private var authenticationSession: ASWebAuthenticationSession?
    private var currentCompletionHandler: ((Result<String, Error>) -> Void)?
    
    override init() {
        super.init()
        loadConnectedServices()
    }
    
    // MARK: - Google Calendar OAuth
    
    func connectGoogleCalendar() async throws {
        isLoading = true
        return try await withCheckedThrowingContinuation { continuation in
            self.currentCompletionHandler = { result in
                switch result {
                case .success(_):
                    continuation.resume(with: .success(()))
                case .failure(let error):
                    continuation.resume(with: .failure(error))
                }
            }
            
            self.startGoogleOAuthFlow(scope: "https://www.googleapis.com/auth/calendar")
        }
    }
    
    // MARK: - Gmail OAuth
    
    func connectGmail() async throws {
        isLoading = true
        return try await withCheckedThrowingContinuation { continuation in
            self.currentCompletionHandler = { result in
                switch result {
                case .success(_):
                    continuation.resume(with: .success(()))
                case .failure(let error):
                    continuation.resume(with: .failure(error))
                }
            }
            
            self.startGoogleOAuthFlow(scope: "https://www.googleapis.com/auth/gmail.readonly")
        }
    }
    
    // MARK: - Airtable OAuth
    
    func connectAirtable() async throws {
        isLoading = true
        return try await withCheckedThrowingContinuation { continuation in
            self.currentCompletionHandler = { result in
                switch result {
                case .success(_):
                    continuation.resume(with: .success(()))
                case .failure(let error):
                    continuation.resume(with: .failure(error))
                }
            }
            
            self.startAirtableOAuthFlow()
        }
    }
    
    // MARK: - Private OAuth Flow Methods
    
    private func startGoogleOAuthFlow(scope: String) {
        // Use backend OAuth endpoint instead of direct OAuth
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let state = "\(deviceId):\(UUID().uuidString)"
        
        let authURL = "\(Constants.API.baseURL)/api/oauth/public/google/init?" +
            "state=\(state)&" +
            "scope=\(scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        // Make API request to get the OAuth URL
        Task {
            do {
                let request = URLRequest(url: URL(string: authURL)!)
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let oauthURL = json["authUrl"] as? String {
                    
                    await MainActor.run {
                        self.startWebAuthSession(url: oauthURL, service: "google", state: state)
                    }
                } else {
                    await MainActor.run {
                        self.handleOAuthError(OAuthError.invalidURL)
                    }
                }
            } catch {
                await MainActor.run {
                    self.handleOAuthError(OAuthError.networkError)
                }
            }
        }
    }
    
    private func startWebAuthSession(url: String, service: String, state: String) {
        guard let authURL = URL(string: url) else {
            handleOAuthError(OAuthError.invalidURL)
            return
        }
        
        authenticationSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "com.amitstoerkel.VoiceAssistant"
        ) { [weak self] callbackURL, error in
            DispatchQueue.main.async {
                self?.handleBackendOAuthCallback(callbackURL: callbackURL, error: error, service: service, state: state)
            }
        }
        
        authenticationSession?.presentationContextProvider = self
        authenticationSession?.prefersEphemeralWebBrowserSession = false
        authenticationSession?.start()
    }
    
    private func startAirtableOAuthFlow() {
        // Use backend OAuth endpoint instead of direct OAuth
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let state = "\(deviceId):\(UUID().uuidString)"
        
        let authURL = "\(Constants.API.baseURL)/api/oauth/public/airtable/init?" +
            "state=\(state)"
        
        // Make API request to get the OAuth URL
        Task {
            do {
                let request = URLRequest(url: URL(string: authURL)!)
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let oauthURL = json["authUrl"] as? String {
                    
                    await MainActor.run {
                        self.startWebAuthSession(url: oauthURL, service: "airtable", state: state)
                    }
                } else {
                    await MainActor.run {
                        self.handleOAuthError(OAuthError.invalidURL)
                    }
                }
            } catch {
                await MainActor.run {
                    self.handleOAuthError(OAuthError.networkError)
                }
            }
        }
    }
    
    private func handleOAuthCallback(callbackURL: URL?, error: Error?, service: String) {
        isLoading = false
        
        if let error = error {
            handleOAuthError(error)
            return
        }
        
        guard let callbackURL = callbackURL else {
            handleOAuthError(OAuthError.noCallbackURL)
            return
        }
        
        // Parse authorization code from callback URL
        guard let code = extractAuthorizationCode(from: callbackURL) else {
            handleOAuthError(OAuthError.noAuthorizationCode)
            return
        }
        
        // Exchange code for access token
        Task {
            do {
                let tokenResponse = try await exchangeCodeForToken(code: code, service: service)
                await handleTokenResponse(tokenResponse, service: service)
            } catch {
                await MainActor.run {
                    self.handleOAuthError(error)
                }
            }
        }
    }
    
    private func extractAuthorizationCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        return queryItems.first { $0.name == "code" }?.value
    }
    
    private func exchangeCodeForToken(code: String, service: String) async throws -> TokenResponse {
        _ = APIClient.shared
        
        // For demo purposes, simulate successful token exchange
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        return TokenResponse(
            accessToken: "mock_access_token_\(service)",
            refreshToken: "mock_refresh_token_\(service)",
            expiresIn: 3600,
            tokenType: "Bearer"
        )
    }
    
    private func handleTokenResponse(_ response: TokenResponse, service: String) async {
        // Store tokens securely
        await saveTokens(response, for: service)
        
        // Update connected services
        await MainActor.run {
            self.connectedServices[service] = ConnectedServiceInfo(
                serviceName: service,
                isConnected: true,
                connectedAt: Date(),
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
            )
            
            self.saveConnectedServices()
        }
        
        // Notify success
        currentCompletionHandler?(.success(response.accessToken))
        currentCompletionHandler = nil
        
        print("✅ Successfully connected to \(service)")
    }
    
    private func handleBackendOAuthCallback(callbackURL: URL?, error: Error?, service: String, state: String) {
        isLoading = false
        
        if let error = error {
            handleOAuthError(error)
            return
        }
        
        guard callbackURL != nil else {
            handleOAuthError(OAuthError.noCallbackURL)
            return
        }
        
        // For backend OAuth, the callback should contain success information
        // The backend has already handled the token exchange
        Task {
            do {
                // Check OAuth completion status with backend
                let statusURL = "\(Constants.API.baseURL)/api/oauth/integrations?deviceId=\(extractDeviceId(from: state))"
                let request = URLRequest(url: URL(string: statusURL)!)
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // Parse the response to check if OAuth was successful
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let integrations = json["integrations"] as? [[String: Any]] {
                        
                        let isConnected = integrations.contains { integration in
                            (integration["type"] as? String) == service && (integration["isConnected"] as? Bool) == true
                        }
                        
                        await MainActor.run {
                            if isConnected {
                                self.updateConnectedService(service: service)
                                self.currentCompletionHandler?(.success("connected"))
                            } else {
                                self.handleOAuthError(OAuthError.tokenExchangeFailed)
                            }
                            self.currentCompletionHandler = nil
                        }
                    }
                } else {
                    await MainActor.run {
                        self.handleOAuthError(OAuthError.networkError)
                    }
                }
            } catch {
                await MainActor.run {
                    self.handleOAuthError(OAuthError.networkError)
                }
            }
        }
    }
    
    private func extractDeviceId(from state: String) -> String {
        return state.components(separatedBy: ":").first ?? ""
    }
    
    private func updateConnectedService(service: String) {
        connectedServices[service] = ConnectedServiceInfo(
            serviceName: service,
            isConnected: true,
            connectedAt: Date(),
            accessToken: "backend_managed",
            refreshToken: nil,
            expiresAt: nil
        )
        saveConnectedServices()
        print("✅ Successfully connected to \(service) via backend")
    }
    
    private func handleOAuthError(_ error: Error) {
        currentCompletionHandler?(.failure(error))
        currentCompletionHandler = nil
        
        print("❌ OAuth error: \(error)")
    }
    
    // MARK: - Token Management
    
    private func storeJWTToken(_ token: String, for deviceId: String) async {
        let keychain = KeychainService.shared
        
        do {
            // Store JWT token for API authentication
            try await keychain.store(token, key: "jwt_token")
            try await keychain.store(deviceId, key: "device_id")
            print("✅ JWT token stored successfully")
        } catch {
            print("❌ Failed to store JWT token: \(error)")
        }
    }
    
    private func saveTokens(_ tokens: TokenResponse, for service: String) async {
        let keychain = KeychainService.shared
        
        do {
            try await keychain.store(tokens.accessToken, key: "\(service)_access_token")
            try await keychain.store(tokens.refreshToken, key: "\(service)_refresh_token")
        } catch {
            print("❌ Failed to save tokens for \(service): \(error)")
        }
    }
    
    private func loadTokens(for service: String) async throws -> TokenResponse {
        let keychain = KeychainService.shared
        
        let accessToken = try await keychain.retrieve(key: "\(service)_access_token")
        let refreshToken = try await keychain.retrieve(key: "\(service)_refresh_token")
        
        return TokenResponse(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: 3600, // Default expiration
            tokenType: "Bearer"
        )
    }
    
    // MARK: - Service Management
    
    func isConnected(_ service: String) -> Bool {
        return connectedServices[service]?.isConnected ?? false
    }
    
    func disconnectService(_ service: String) async {
        // Remove from connected services
        await MainActor.run {
            connectedServices.removeValue(forKey: service)
            saveConnectedServices()
        }
        
        // Remove tokens from keychain
        let keychain = KeychainService.shared
        try? await keychain.delete(key: "\(service)_access_token")
        try? await keychain.delete(key: "\(service)_refresh_token")
        
        print("🔌 Disconnected from \(service)")
    }
    
    private func saveConnectedServices() {
        if let data = try? JSONEncoder().encode(connectedServices) {
            UserDefaults.standard.set(data, forKey: "connected_services")
        }
    }
    
    private func loadConnectedServices() {
        guard let data = UserDefaults.standard.data(forKey: "connected_services"),
              let services = try? JSONDecoder().decode([String: ConnectedServiceInfo].self, from: data) else {
            return
        }
        
        connectedServices = services
    }
    
    // MARK: - URL Callback Handling
    
    func handleSuccessCallback(success: String, params: [String: String]) async {
        print("✅ OAuth success callback: \(success)")
        
        // Determine the service from the success message
        let service: String
        if success.contains("google") {
            service = "google"
        } else if success.contains("airtable") {
            service = "airtable"
        } else {
            service = "unknown"
        }
        
        // Extract JWT token and deviceId from params
        if let jwtToken = params["token"], let deviceId = params["deviceId"] {
            // Store the JWT token for backend communication
            await storeJWTToken(jwtToken, for: deviceId)
        }
        
        await MainActor.run {
            self.updateConnectedService(service: service)
            // Refresh integration status in OAuth manager
            NotificationCenter.default.post(name: .oauthStatusChanged, object: nil)
            print("✅ OAuth success processed for \(service)")
            
            // Refresh APIClient authentication status since we now have JWT token
            APIClient.shared.refreshAuthenticationStatus()
            print("🔍 Refreshed APIClient authentication status after OAuth completion")
            
            // Complete any pending OAuth flows
            if let completionHandler = self.currentCompletionHandler {
                completionHandler(.success("connected"))
                self.currentCompletionHandler = nil
            }
            
            self.isLoading = false
        }
    }
    
    func handleErrorCallback(error: String) async {
        print("❌ OAuth error callback: \(error)")
        
        await MainActor.run {
            // Complete any pending OAuth flows with error
            if let completionHandler = self.currentCompletionHandler {
                completionHandler(.failure(OAuthError.tokenExchangeFailed))
                self.currentCompletionHandler = nil
            }
            
            self.isLoading = false
        }
    }
    
    func handleCallback(params: [String: String]) async {
        print("🔄 Processing OAuth callback with params: \(params)")
        
        // Extract parameters
        guard let code = params["code"],
              let state = params["state"] else {
            print("❌ Missing required OAuth parameters")
            await MainActor.run {
                self.handleOAuthError(OAuthError.noAuthorizationCode)
            }
            return
        }
        
        // Determine service from callback (could be enhanced with state parsing)
        let service = params["service"] ?? "google" // Default to google for now
        
        print("🔄 Exchanging code for token for service: \(service)")
        
        // Exchange code for token via backend
        do {
            let success = try await exchangeCodeViaBackend(code: code, state: state, service: service)
            if success {
                await MainActor.run {
                    self.updateConnectedService(service: service)
                    // Refresh integration status in OAuth manager
                    NotificationCenter.default.post(name: .oauthStatusChanged, object: nil)
                    print("✅ OAuth callback processed successfully for \(service)")
                }
            } else {
                await MainActor.run {
                    self.handleOAuthError(OAuthError.tokenExchangeFailed)
                }
            }
        } catch {
            await MainActor.run {
                self.handleOAuthError(error)
            }
        }
    }
    
    private func exchangeCodeViaBackend(code: String, state: String, service: String) async throws -> Bool {
        let deviceId = extractDeviceId(from: state)
        let endpoint = "\(Constants.API.baseURL)/api/oauth/public/\(service)/callback"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "code": code,
            "state": state,
            "deviceId": deviceId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 Backend OAuth response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📡 Backend OAuth response: \(json)")
                    return json["success"] as? Bool ?? false
                }
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Token Refresh
    
    func refreshTokens() async {
        for (service, info) in connectedServices {
            if info.isTokenExpired, let refreshTokenValue = info.refreshToken {
                do {
                    let newTokens = try await refreshToken(for: service, refreshToken: refreshTokenValue)
                    await handleTokenResponse(newTokens, service: service)
                } catch {
                    print("❌ Failed to refresh token for \(service): \(error)")
                }
            }
        }
    }
    
    private func refreshToken(for service: String, refreshToken: String) async throws -> TokenResponse {
        // Implement token refresh logic for each service
        throw OAuthError.tokenRefreshFailed
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("Unable to get window for OAuth presentation")
        }
        return window
    }
}

// MARK: - Models

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
}

struct ConnectedServiceInfo: Codable {
    let serviceName: String
    let isConnected: Bool
    let connectedAt: Date
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    
    var isTokenExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}

// MARK: - Errors

enum OAuthError: Error, LocalizedError {
    case invalidURL
    case noCallbackURL
    case noAuthorizationCode
    case tokenExchangeFailed
    case tokenRefreshFailed
    case keychainError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid OAuth URL"
        case .noCallbackURL:
            return "No callback URL received"
        case .noAuthorizationCode:
            return "No authorization code found"
        case .tokenExchangeFailed:
            return "Failed to exchange code for token"
        case .tokenRefreshFailed:
            return "Failed to refresh token"
        case .keychainError:
            return "Keychain operation failed"
        case .networkError:
            return "Network connection error"
        }
    }
}

// MARK: - Keychain Service

class KeychainService {
    static let shared = KeychainService()
    private init() {}
    
    func store(_ value: String, key: String) async throws {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw OAuthError.keychainError
        }
    }
    
    func retrieve(key: String) async throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            throw OAuthError.keychainError
        }
        
        guard let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw OAuthError.keychainError
        }
        
        return string
    }
    
    func delete(key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw OAuthError.keychainError
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let oauthStatusChanged = Notification.Name("OAuthStatusChanged")
}