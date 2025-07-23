//
//  APIClient.swift
//  VoiceAssistant
//
//  Created by Amit Störkel on 16.07.25.
//
import Foundation
import UIKit

public class APIClient: ObservableObject {
    public static let shared = APIClient()
    
    private let baseURL: String
    private let session: URLSession
    private var accessToken: String?
    private var refreshToken: String?
    private let webSocketManager = WebSocketManager.shared
    
    @Published var isConnected = false
    @Published var lastError: Error?
    @Published var isAuthenticated = false
    @Published var isWebSocketConnected = false
    @Published var isReachable = false
    
    init(baseURL: String = Constants.API.baseURL) {
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.API.requestTimeout
        config.timeoutIntervalForResource = Constants.API.requestTimeout
        self.session = URLSession(configuration: config)
        
        // Load stored tokens
        loadTokens()
        
        // Setup WebSocket callbacks
        setupWebSocketCallbacks()
        
        // Connect to WebSocket if authenticated (but not in development mode)
        if isAuthenticated && !UserDefaults.standard.bool(forKey: "development_mode") {
            connectWebSocket()
        }
    }
    
    private func loadTokens() {
        self.accessToken = UserDefaults.standard.string(forKey: Constants.StorageKeys.accessToken)
        self.refreshToken = UserDefaults.standard.string(forKey: Constants.StorageKeys.refreshToken)
        self.isAuthenticated = (accessToken != nil)
    }
    
    private func saveTokens(accessToken: String, refreshToken: String) {
        UserDefaults.standard.set(accessToken, forKey: Constants.StorageKeys.accessToken)
        UserDefaults.standard.set(refreshToken, forKey: Constants.StorageKeys.refreshToken)
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        DispatchQueue.main.async {
            self.isAuthenticated = true
        }
        
        // Connect to WebSocket after authentication
        connectWebSocket()
    }
    
    private func addCommonHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.API.apiKey, forHTTPHeaderField: "x-api-key")
        
        if let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
    }
    
    private func clearTokens() {
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.accessToken)
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.refreshToken)
        self.accessToken = nil
        self.refreshToken = nil
        DispatchQueue.main.async {
            self.isAuthenticated = false
        }
        
        // Disconnect WebSocket
        webSocketManager.disconnect()
    }
    
    // MARK: - Public Authentication Methods
    
    func setAuthToken(_ token: String) {
        self.accessToken = token
        UserDefaults.standard.set(token, forKey: Constants.StorageKeys.accessToken)
        DispatchQueue.main.async {
            self.isAuthenticated = true
        }
        
        // Connect to WebSocket after authentication
        connectWebSocket()
    }
    
    // MARK: - WebSocket Management
    
    private func setupWebSocketCallbacks() {
        webSocketManager.onConnectionStatusChanged = { [weak self] connected in
            DispatchQueue.main.async {
                self?.isWebSocketConnected = connected
            }
        }
        
        webSocketManager.onAuthError = { error in
            print("❌ WebSocket authentication error: \(error)")
            // Handle auth error - might need to refresh tokens
        }
        
        webSocketManager.onAuthenticated = { [weak self] in
            print("✅ WebSocket authenticated")
            self?.webSocketManager.startHealthCheck()
        }
    }
    
    private func connectWebSocket() {
        guard let accessToken = accessToken else {
            print("❌ No access token available for WebSocket connection")
            return
        }
        
        webSocketManager.connect(accessToken: accessToken)
    }
    
    // MARK: - Authentication Methods
    
    func authenticateWithApple(idToken: String, user: [String: Any]?, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/auth/apple-signin") else {
            completion(.failure(VoiceAssistantError.networkError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)
        
        let body: [String: Any] = [
            "idToken": idToken,
            "user": user ?? [:]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode,
                  let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.networkError))
                }
                return
            }
            
            do {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                self?.saveTokens(accessToken: authResponse.accessToken, refreshToken: authResponse.refreshToken)
                DispatchQueue.main.async {
                    completion(.success(true))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func logout(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/auth/logout") else {
            completion(.failure(VoiceAssistantError.networkError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addCommonHeaders(to: &request)
        
        if let refreshToken = refreshToken {
            let body: [String: Any] = ["refreshToken": refreshToken]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        session.dataTask(with: request) { [weak self] data, response, error in
            // Clear tokens regardless of response
            self?.clearTokens()
            
            DispatchQueue.main.async {
                completion(.success(true))
            }
        }.resume()
    }
    
    private func refreshAccessToken(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let refreshToken = refreshToken,
              let url = URL(string: "\(baseURL)/api/auth/refresh") else {
            completion(.failure(VoiceAssistantError.networkError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)
        
        let body: [String: Any] = ["refreshToken": refreshToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode,
                  let data = data else {
                self?.clearTokens()
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.networkError))
                }
                return
            }
            
            do {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                self?.saveTokens(accessToken: authResponse.accessToken, refreshToken: authResponse.refreshToken)
                DispatchQueue.main.async {
                    completion(.success(true))
                }
            } catch {
                self?.clearTokens()
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Voice Command Methods
    
    /// Process voice command with processing flags for hybrid decision making
    func processVoiceCommandWithFlags(
        text: String,
        audioData: Data? = nil,
        processingFlags: ProcessingFlags,
        context: APIVoiceContext
    ) async throws -> ServerVoiceResponse {
        guard isAuthenticated else {
            throw VoiceAssistantError.authenticationRequired
        }
        
        let endpoint = audioData != nil ? "/api/voice/process-audio" : "/api/voice/process-text"
        
        if let audioData = audioData {
            // Use multipart request for audio
            return try await processAudioWithFlags(audioData: audioData, processingFlags: processingFlags, context: context)
        } else {
            // Use JSON request for text
            return try await processTextWithFlags(text: text, processingFlags: processingFlags, context: context)
        }
    }
    
    private func processTextWithFlags(
        text: String,
        processingFlags: ProcessingFlags,
        context: APIVoiceContext
    ) async throws -> ServerVoiceResponse {
        guard let url = URL(string: "\(baseURL)/api/voice/process-text") else {
            throw VoiceAssistantError.networkError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)
        
        if let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let requestBody: [String: Any] = [
            "text": text,
            "context": [
                "sessionId": context.sessionId,
                "platform": context.platform,
                "deviceModel": context.deviceModel,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            "processingFlags": [
                "onDeviceCapable": processingFlags.onDeviceCapable,
                "complexityScore": processingFlags.complexityScore,
                "privacyRequired": processingFlags.privacyRequired,
                "resourceConstraints": [
                    "batteryLevel": processingFlags.resourceConstraints.batteryLevel,
                    "networkQuality": processingFlags.resourceConstraints.networkQuality.rawValue,
                    "memoryPressure": processingFlags.resourceConstraints.memoryPressure,
                    "thermalState": processingFlags.resourceConstraints.thermalState
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw VoiceAssistantError.networkError
        }
        
        let backendResponse = try JSONDecoder().decode(BackendVoiceResponse.self, from: data)
        return ServerVoiceResponse(from: backendResponse)
    }
    
    private func processAudioWithFlags(
        audioData: Data,
        processingFlags: ProcessingFlags,
        context: APIVoiceContext
    ) async throws -> ServerVoiceResponse {
        guard let url = URL(string: "\(baseURL)/api/voice/process-audio") else {
            throw VoiceAssistantError.networkError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.API.apiKey, forHTTPHeaderField: "x-api-key")
        
        if let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        
        // Add sessionId field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"sessionId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(context.sessionId)\r\n".data(using: .utf8)!)
        
        // Add processing flags
        let processingFlagsData = try JSONSerialization.data(withJSONObject: [
            "onDeviceCapable": processingFlags.onDeviceCapable,
            "complexityScore": processingFlags.complexityScore,
            "privacyRequired": processingFlags.privacyRequired,
            "resourceConstraints": [
                "batteryLevel": processingFlags.resourceConstraints.batteryLevel,
                "networkQuality": processingFlags.resourceConstraints.networkQuality.rawValue,
                "memoryPressure": processingFlags.resourceConstraints.memoryPressure,
                "thermalState": processingFlags.resourceConstraints.thermalState
            ]
        ])
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"processingFlags\"\r\n\r\n".data(using: .utf8)!)
        body.append(processingFlagsData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw VoiceAssistantError.networkError
        }
        
        let backendResponse = try JSONDecoder().decode(BackendVoiceResponse.self, from: data)
        return ServerVoiceResponse(from: backendResponse)
    }
    
    /// Check if on-device processing is available for the given text
    func checkOnDeviceCapability(for text: String) -> OnDeviceCapabilityResult {
        // Basic heuristics for on-device capability
        let wordCount = text.split(separator: " ").count
        let complexity = calculateTextComplexity(text)
        
        let canProcessLocally = wordCount <= 20 && complexity < 0.7
        let confidence = canProcessLocally ? 0.8 : 0.3
        
        return OnDeviceCapabilityResult(
            canProcessLocally: canProcessLocally,
            confidence: confidence,
            estimatedProcessingTime: wordCount < 10 ? 0.5 : 1.2,
            supportedCapabilities: getSupportedCapabilities(for: text)
        )
    }
    
    private func calculateTextComplexity(_ text: String) -> Double {
        let hasQuestions = text.contains("?")
        let hasComplexWords = text.split(separator: " ").contains { $0.count > 8 }
        let hasNumbers = text.rangeOfCharacter(from: .decimalDigits) != nil
        
        var complexity = 0.0
        if hasQuestions { complexity += 0.3 }
        if hasComplexWords { complexity += 0.2 }
        if hasNumbers { complexity += 0.1 }
        
        return min(complexity, 1.0)
    }
    
    private func getSupportedCapabilities(for text: String) -> [OnDeviceCapability] {
        var capabilities: [OnDeviceCapability] = []
        
        let lowercaseText = text.lowercased()
        
        if lowercaseText.contains("time") || lowercaseText.contains("date") {
            capabilities.append(.timeQueries)
        }
        
        if lowercaseText.contains("calculate") || lowercaseText.contains("math") {
            capabilities.append(.basicCalculations)
        }
        
        if lowercaseText.contains("calendar") || lowercaseText.contains("meeting") {
            capabilities.append(.cachedCalendar)
        }
        
        if lowercaseText.contains("contact") || lowercaseText.contains("call") {
            capabilities.append(.cachedContacts)
        }
        
        if lowercaseText.contains("weather") {
            capabilities.append(.cachedWeather)
        }
        
        if lowercaseText.contains("reminder") || lowercaseText.contains("note") {
            capabilities.append(.simpleReminders)
        }
        
        return capabilities
    }
    
    func sendVoiceCommand(_ request: VoiceRequest, completion: @escaping (Result<VoiceResponse, Error>) -> Void) {
        guard isAuthenticated else {
            completion(.failure(VoiceAssistantError.authenticationRequired))
            return
        }
        
        // Try WebSocket first if connected
        if isWebSocketConnected {
            // Set up one-time callback for this request
            webSocketManager.onVoiceResponse = { response in
                completion(.success(response))
            }
            
            webSocketManager.onVoiceError = { error in
                completion(.failure(VoiceAssistantError.networkError))
            }
            
            webSocketManager.sendVoiceCommand(request)
        } else {
            // Fall back to HTTP API
            performAuthenticatedRequest(endpoint: "/api/voice/process-text", method: "POST", body: request) { result in
                switch result {
                case .success(let data):
                    self.parseVoiceResponse(data) { result in
                        switch result {
                        case .success(let enhancedResponse):
                            // Convert enhanced response to basic response for compatibility
                            completion(.success(enhancedResponse.voiceResponse))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // New method that returns enhanced response
    func sendVoiceCommandEnhanced(_ request: VoiceRequest, completion: @escaping (Result<EnhancedVoiceResponse, Error>) -> Void) {
        guard isAuthenticated else {
            completion(.failure(VoiceAssistantError.authenticationRequired))
            return
        }
        
        // Use HTTP API for enhanced responses
        performAuthenticatedRequest(endpoint: "/api/voice/process-text", method: "POST", body: request) { result in
            switch result {
            case .success(let data):
                self.parseVoiceResponse(data, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func sendVoiceAudio(_ audioData: Data, sessionId: String, completion: @escaping (Result<VoiceResponse, Error>) -> Void) {
        guard isAuthenticated else {
            completion(.failure(VoiceAssistantError.authenticationRequired))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/voice/process-audio") else {
            completion(.failure(VoiceAssistantError.networkError))
            return
        }
        
        performAuthenticatedMultipartRequest(url: url, audioData: audioData, sessionId: sessionId) { result in
            switch result {
            case .success(let data):
                self.parseVoiceResponse(data) { enhancedResult in
                    switch enhancedResult {
                    case .success(let enhancedResponse):
                        completion(.success(enhancedResponse.voiceResponse))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func performAuthenticatedRequest<T: Codable>(endpoint: String, method: String, body: T?, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(VoiceAssistantError.networkError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        addCommonHeaders(to: &request)
        
        if let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        performRequest(request: request, completion: completion)
    }
    
    private func performAuthenticatedMultipartRequest(url: URL, audioData: Data, sessionId: String, completion: @escaping (Result<Data, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.API.apiKey, forHTTPHeaderField: "x-api-key")
        
        if let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        
        // Add sessionId field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"sessionId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(sessionId)\r\n".data(using: .utf8)!)
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        performRequest(request: request, completion: completion)
    }
    
    private func performRequest(request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        // DEBUG: Log request details
        print("🌐 API REQUEST DEBUG:")
        print("   URL: \(request.url?.absoluteString ?? "nil")")
        print("   Method: \(request.httpMethod ?? "nil")")
        print("   Headers:")
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            if key == "Authorization" {
                print("     \(key): \(value.prefix(20))...")
            } else {
                print("     \(key): \(value)")
            }
        }
        
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ REQUEST ERROR: \(error)")
                DispatchQueue.main.async {
                    self?.lastError = error
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ INVALID HTTP RESPONSE")
                DispatchQueue.main.async {
                    self?.lastError = VoiceAssistantError.networkError
                    completion(.failure(VoiceAssistantError.networkError))
                }
                return
            }
            
            print("📡 RESPONSE DEBUG:")
            print("   Status Code: \(httpResponse.statusCode)")
            print("   Headers: \(httpResponse.allHeaderFields)")
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("   Response Body: \(responseString.prefix(500))...")
            }
            
            // Handle 401 by attempting token refresh
            if httpResponse.statusCode == 401 {
                print("🚨 401 UNAUTHORIZED - Attempting token refresh")
                self?.refreshAccessToken { result in
                    switch result {
                    case .success:
                        print("✅ Token refreshed successfully, retrying request")
                        // Retry the original request
                        self?.performRequest(request: request, completion: completion)
                    case .failure(let error):
                        print("❌ Token refresh failed: \(error)")
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    }
                }
                return
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                let error = self?.mapHTTPStatusToError(httpResponse.statusCode) ?? VoiceAssistantError.networkError
                DispatchQueue.main.async {
                    self?.lastError = error
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self?.lastError = VoiceAssistantError.invalidResponse
                    completion(.failure(VoiceAssistantError.invalidResponse))
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.isConnected = true
                completion(.success(data))
            }
        }.resume()
    }
    
    private func mapHTTPStatusToError(_ statusCode: Int) -> VoiceAssistantError {
        switch statusCode {
        case 400:
            return .invalidResponse
        case 401:
            return .tokenExpired
        case 403:
            return .authenticationFailed
        case 404:
            return .backendUnavailable
        case 429:
            return .rateLimitExceeded
        case 500...599:
            return .serverError(statusCode)
        default:
            return .unknownError("HTTP \(statusCode)")
        }
    }
    
    private func parseVoiceResponse(_ data: Data, completion: @escaping (Result<EnhancedVoiceResponse, Error>) -> Void) {
        do {
            let backendResponse = try JSONDecoder().decode(BackendVoiceResponse.self, from: data)
            
            // Convert backend response to enhanced response
            let response = EnhancedVoiceResponse(from: backendResponse)
            
            DispatchQueue.main.async {
                completion(.success(response))
            }
        } catch {
            print("❌ Failed to parse voice response: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("❌ Response JSON: \(jsonString)")
            }
            DispatchQueue.main.async {
                self.lastError = error
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - WebSocket Methods
    
    func sendVoiceStreamStart(sessionId: String) {
        guard isWebSocketConnected else {
            print("❌ WebSocket not connected, cannot start voice stream")
            return
        }
        
        webSocketManager.sendVoiceStream(audioData: Data(), sessionId: sessionId, isEnd: false)
    }
    
    func sendVoiceStreamChunk(audioData: Data, sessionId: String) {
        guard isWebSocketConnected else {
            print("❌ WebSocket not connected, cannot send voice stream chunk")
            return
        }
        
        webSocketManager.sendVoiceStream(audioData: audioData, sessionId: sessionId, isEnd: false)
    }
    
    func sendVoiceStreamEnd(sessionId: String) {
        guard isWebSocketConnected else {
            print("❌ WebSocket not connected, cannot end voice stream")
            return
        }
        
        webSocketManager.sendVoiceStream(audioData: Data(), sessionId: sessionId, isEnd: true)
    }
    
    func getConversationHistory(limit: Int = 20) {
        guard isWebSocketConnected else {
            print("❌ WebSocket not connected, cannot get conversation history")
            return
        }
        
        webSocketManager.getConversationHistory(limit: limit)
    }
    
    func clearConversationHistory() {
        guard isWebSocketConnected else {
            print("❌ WebSocket not connected, cannot clear conversation history")
            return
        }
        
        webSocketManager.clearConversationHistory()
    }
    
    // MARK: - Generic HTTP Methods
    
    func get(_ endpoint: String, queryParams: [String: String]? = nil) async throws -> [String: Any] {
        var urlComponents = URLComponents(string: "\(baseURL)\(endpoint)")
        
        if let queryParams = queryParams {
            urlComponents?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = urlComponents?.url else {
            throw VoiceAssistantError.networkError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addCommonHeaders(to: &request)
        
        if let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw VoiceAssistantError.networkError
        }
        
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    func post(_ endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw VoiceAssistantError.networkError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)
        
        if let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw VoiceAssistantError.networkError
        }
        
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    func put(_ endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw VoiceAssistantError.networkError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        addCommonHeaders(to: &request)
        
        if let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw VoiceAssistantError.networkError
        }
        
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    func delete(_ endpoint: String) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw VoiceAssistantError.networkError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addCommonHeaders(to: &request)
        
        if let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw VoiceAssistantError.networkError
        }
        
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    // MARK: - User Preferences Methods
    
    func updateUserPreferences(_ preferences: UserPreferences) async throws -> Bool {
        guard isAuthenticated else {
            throw VoiceAssistantError.authenticationRequired
        }
        
        guard let url = URL(string: "\(baseURL)/api/user/preferences") else {
            throw VoiceAssistantError.networkError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        addCommonHeaders(to: &request)
        
        if let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(preferences)
        } catch {
            throw VoiceAssistantError.networkError
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceAssistantError.networkError
        }
        
        // Handle 401 by attempting token refresh
        if httpResponse.statusCode == 401 {
            return try await withCheckedThrowingContinuation { continuation in
                refreshAccessToken { result in
                    switch result {
                    case .success:
                        Task {
                            do {
                                let success = try await self.updateUserPreferences(preferences)
                                continuation.resume(returning: success)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let error = mapHTTPStatusToError(httpResponse.statusCode)
            throw error
        }
        
        do {
            let response = try JSONDecoder().decode(UserPreferencesResponse.self, from: data)
            return response.success
        } catch {
            throw VoiceAssistantError.invalidResponse
        }
    }
    
    func getUserPreferences() async throws -> UserPreferences {
        guard isAuthenticated else {
            throw VoiceAssistantError.authenticationRequired
        }
        
        guard let url = URL(string: "\(baseURL)/api/user/preferences") else {
            throw VoiceAssistantError.networkError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addCommonHeaders(to: &request)
        
        if let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceAssistantError.networkError
        }
        
        // Handle 401 by attempting token refresh
        if httpResponse.statusCode == 401 {
            return try await withCheckedThrowingContinuation { continuation in
                refreshAccessToken { result in
                    switch result {
                    case .success:
                        Task {
                            do {
                                let preferences = try await self.getUserPreferences()
                                continuation.resume(returning: preferences)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let error = mapHTTPStatusToError(httpResponse.statusCode)
            throw error
        }
        
        do {
            let response = try JSONDecoder().decode(UserPreferencesResponse.self, from: data)
            return response.preferences ?? UserPreferences()
        } catch {
            throw VoiceAssistantError.invalidResponse
        }
    }
}

// MARK: - Hybrid Processing Support Types

/// Processing flags sent to server for hybrid decision making
public struct ProcessingFlags {
    let onDeviceCapable: Bool
    let complexityScore: Double
    let privacyRequired: Bool
    let resourceConstraints: ResourceConstraints
}

/// Resource constraints for processing decisions
public struct ResourceConstraints {
    let batteryLevel: Float
    let networkQuality: NetworkQuality
    let memoryPressure: Float
    let thermalState: String
}

/// Network quality assessment
public enum NetworkQuality: String, CaseIterable, Codable, Comparable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case unavailable = "unavailable"
    
    public static func < (lhs: NetworkQuality, rhs: NetworkQuality) -> Bool {
        let order: [NetworkQuality] = [.unavailable, .poor, .fair, .good, .excellent]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

/// Voice processing context for API calls
public struct APIVoiceContext {
    let sessionId: String
    let platform: String
    let deviceModel: String
    
    public init(sessionId: String = UUID().uuidString, platform: String = "iOS", deviceModel: String = UIDevice.current.model) {
        self.sessionId = sessionId
        self.platform = platform
        self.deviceModel = deviceModel
    }
}

/// Server voice response with enhanced metadata
public struct ServerVoiceResponse {
    public let response: String
    public let audioBase64: String?
    public let confidence: Double
    public let serverProcessingTime: TimeInterval
    public let modelUsed: String?
    public let tokensConsumed: Int?
    
    internal init(from backendResponse: BackendVoiceResponse) {
        self.response = backendResponse.response?.text ?? ""
        self.audioBase64 = backendResponse.audioResponse?.audioBase64
        self.confidence = backendResponse.confidence ?? 0
        self.serverProcessingTime = TimeInterval(backendResponse.processingTime ?? 0) / 1000.0
        self.modelUsed = backendResponse.agentUsed
        self.tokensConsumed = nil // Not available in current backend response
    }
}

/// On-device capability result
public struct OnDeviceCapabilityResult {
    public let canProcessLocally: Bool
    public let confidence: Double
    public let estimatedProcessingTime: TimeInterval
    public let supportedCapabilities: [OnDeviceCapability]
}

/// On-device capabilities
public enum OnDeviceCapability: String, CaseIterable {
    case timeQueries = "time_queries"
    case basicCalculations = "basic_calculations"
    case cachedCalendar = "cached_calendar"
    case cachedContacts = "cached_contacts"
    case cachedWeather = "cached_weather"
    case simpleReminders = "simple_reminders"
    case deviceControl = "device_control"
    case conversationHistory = "conversation_history"
}
