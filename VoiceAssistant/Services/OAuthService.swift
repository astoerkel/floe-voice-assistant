//
//  OAuthService.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import Foundation
import AuthenticationServices
import SafariServices

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
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.isLoading = true
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
    }
    
    // MARK: - Gmail OAuth
    
    func connectGmail() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.isLoading = true
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
    }
    
    // MARK: - Airtable OAuth
    
    func connectAirtable() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.isLoading = true
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
    }
    
    // MARK: - Private OAuth Flow Methods
    
    private func startGoogleOAuthFlow(scope: String) {
        let clientId = "YOUR_GOOGLE_CLIENT_ID" // Replace with actual client ID
        let redirectURI = "com.voiceassistant://oauth/callback"
        
        let authURL = "https://accounts.google.com/o/oauth2/v2/auth?" +
            "client_id=\(clientId)&" +
            "redirect_uri=\(redirectURI)&" +
            "response_type=code&" +
            "scope=\(scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&" +
            "access_type=offline"
        
        guard let url = URL(string: authURL) else {
            handleOAuthError(OAuthError.invalidURL)
            return
        }
        
        authenticationSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "com.voiceassistant"
        ) { [weak self] callbackURL, error in
            DispatchQueue.main.async {
                self?.handleOAuthCallback(callbackURL: callbackURL, error: error, service: "google")
            }
        }
        
        authenticationSession?.presentationContextProvider = self
        authenticationSession?.prefersEphemeralWebBrowserSession = false
        authenticationSession?.start()
    }
    
    private func startAirtableOAuthFlow() {
        let clientId = "YOUR_AIRTABLE_CLIENT_ID" // Replace with actual client ID
        let redirectURI = "com.voiceassistant://oauth/callback"
        
        let authURL = "https://airtable.com/oauth2/v1/authorize?" +
            "client_id=\(clientId)&" +
            "redirect_uri=\(redirectURI)&" +
            "response_type=code&" +
            "scope=data.records:read data.records:write"
        
        guard let url = URL(string: authURL) else {
            handleOAuthError(OAuthError.invalidURL)
            return
        }
        
        authenticationSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "com.voiceassistant"
        ) { [weak self] callbackURL, error in
            DispatchQueue.main.async {
                self?.handleOAuthCallback(callbackURL: callbackURL, error: error, service: "airtable")
            }
        }
        
        authenticationSession?.presentationContextProvider = self
        authenticationSession?.prefersEphemeralWebBrowserSession = false
        authenticationSession?.start()
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
    
    private func handleOAuthError(_ error: Error) {
        currentCompletionHandler?(.failure(error))
        currentCompletionHandler = nil
        
        print("❌ OAuth error: \(error)")
    }
    
    // MARK: - Token Management
    
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
    
    // MARK: - Token Refresh
    
    func refreshTokens() async {
        for (service, info) in connectedServices {
            if info.isTokenExpired {
                do {
                    let newTokens = try await refreshToken(for: service, refreshToken: info.refreshToken)
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
    let refreshToken: String
    let expiresAt: Date
    
    var isTokenExpired: Bool {
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