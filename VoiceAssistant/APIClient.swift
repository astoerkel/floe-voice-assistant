//
//  APIClient.swift
//  VoiceAssistant
//
//  Created by Amit Störkel on 16.07.25.
//
import Foundation

class APIClient: ObservableObject {
    static let shared = APIClient()
    
    private let baseURL: String
    private let session: URLSession
    private var accessToken: String?
    private var refreshToken: String?
    private let webSocketManager = WebSocketManager.shared
    
    @Published var isConnected = false
    @Published var lastError: Error?
    @Published var isAuthenticated = false
    @Published var isWebSocketConnected = false
    
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
    
    // MARK: - WebSocket Management
    
    private func setupWebSocketCallbacks() {
        webSocketManager.onConnectionStatusChanged = { [weak self] connected in
            DispatchQueue.main.async {
                self?.isWebSocketConnected = connected
            }
        }
        
        webSocketManager.onAuthError = { [weak self] error in
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
            performAuthenticatedRequest(endpoint: "/api/voice/process", method: "POST", body: request) { result in
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
        performAuthenticatedRequest(endpoint: "/api/voice/process", method: "POST", body: request) { result in
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.lastError = error
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self?.lastError = VoiceAssistantError.networkError
                    completion(.failure(VoiceAssistantError.networkError))
                }
                return
            }
            
            // Handle 401 by attempting token refresh
            if httpResponse.statusCode == 401 {
                self?.refreshAccessToken { result in
                    switch result {
                    case .success:
                        // Retry the original request
                        self?.performRequest(request: request, completion: completion)
                    case .failure(let error):
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
            
            // Create enhanced response with backend information
            let response = EnhancedVoiceResponse(
                text: backendResponse.response ?? "",
                success: backendResponse.success,
                audioBase64: backendResponse.audioResponse?.audioBase64,
                intent: backendResponse.intent,
                confidence: backendResponse.confidence,
                agentUsed: backendResponse.agentUsed,
                executionTime: backendResponse.executionTime,
                actions: backendResponse.actions,
                suggestions: backendResponse.suggestions
            )
            
            DispatchQueue.main.async {
                completion(.success(response))
            }
        } catch {
            print("❌ Failed to parse voice response: \(error)")
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
}
