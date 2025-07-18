//
//  WatchAPIClient.swift
//  VoiceAssistant Watch App
//
//  Created by Amit Störkel on 17.07.25.
//

import Foundation

// MARK: - Watch Constants
private struct WatchConstants {
    struct API {
        static let baseURL = "https://voiceassistant-sora-production.up.railway.app"
        static let webhookURL = "https://0s1sa1fd.rpcld.co/webhook-test/c8609ff3-adfe-4982-804a-5792f41f4443" // Legacy - to be removed
        static let defaultVoiceId = "default"
        static let requestTimeout: TimeInterval = 30.0
    }
    
    struct StorageKeys {
        static let sessionId = "voice_assistant_session_id"
        static let accessToken = "voice_assistant_access_token"
        static let refreshToken = "voice_assistant_refresh_token"
    }
    
    static func getCurrentSessionId() -> String {
        let defaults = UserDefaults.standard
        if let existingId = defaults.string(forKey: StorageKeys.sessionId) {
            return existingId
        }
        
        let newId = UUID().uuidString.lowercased()
        defaults.set(newId, forKey: StorageKeys.sessionId)
        return newId
    }
}

class WatchAPIClient: ObservableObject {
    static let shared = WatchAPIClient()
    
    private let baseURL: String
    private let session: URLSession
    private var accessToken: String?
    private var refreshToken: String?
    
    @Published var isConnected = true // Default to true, let actual requests fail if needed
    @Published var lastError: Error?
    @Published var isProcessing = false
    @Published var isAuthenticated = false
    
    init(baseURL: String = WatchConstants.API.baseURL) {
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = WatchConstants.API.requestTimeout
        config.timeoutIntervalForResource = WatchConstants.API.requestTimeout
        self.session = URLSession(configuration: config)
        
        // Enable development mode by default for Watch app
        enableDevelopmentMode()
        
        // Load stored tokens
        loadTokens()
        
        // Check initial connectivity
        checkConnectivity()
    }
    
    private func loadTokens() {
        // Check for development mode first
        if UserDefaults.standard.bool(forKey: "development_mode") {
            print("🔧 Watch: Development mode enabled, using mock tokens")
            self.accessToken = "mock_access_token_for_development"
            self.refreshToken = "mock_refresh_token_for_development"
            self.isAuthenticated = true
            
            // Also save to UserDefaults for consistency
            UserDefaults.standard.set(self.accessToken, forKey: WatchConstants.StorageKeys.accessToken)
            UserDefaults.standard.set(self.refreshToken, forKey: WatchConstants.StorageKeys.refreshToken)
            return
        }
        
        // Try to load from shared UserDefaults (using app group)
        if let accessToken = UserDefaults.standard.string(forKey: WatchConstants.StorageKeys.accessToken) {
            self.accessToken = accessToken
            self.refreshToken = UserDefaults.standard.string(forKey: WatchConstants.StorageKeys.refreshToken)
            self.isAuthenticated = true
        } else {
            // Try to get tokens from iPhone via WatchConnectivity
            requestTokensFromiPhone()
        }
    }
    
    private func requestTokensFromiPhone() {
        // Implementation would depend on WatchConnectivity setup
        // For now, mark as not authenticated
        self.isAuthenticated = false
    }
    
    private func clearTokens() {
        UserDefaults.standard.removeObject(forKey: WatchConstants.StorageKeys.accessToken)
        UserDefaults.standard.removeObject(forKey: WatchConstants.StorageKeys.refreshToken)
        self.accessToken = nil
        self.refreshToken = nil
        self.isAuthenticated = false
    }
    
    private func enableDevelopmentMode() {
        print("🔧 Watch: Enabling development mode")
        UserDefaults.standard.set(true, forKey: "development_mode")
        
        // Try to set the same development tokens as the iPhone app
        let devAccessToken = "mock_access_token_for_development"
        let devRefreshToken = "mock_refresh_token_for_development"
        
        UserDefaults.standard.set(devAccessToken, forKey: "voice_assistant_access_token")
        UserDefaults.standard.set(devRefreshToken, forKey: "voice_assistant_refresh_token")
        
        print("🔧 Watch: Set development tokens matching iPhone app")
    }
    
    func updateWebhookURL(_ newURL: String) {
        // This method is kept for backward compatibility
        // The webhook URL is defined in WatchConstants.API.webhookURL
        print("📝 Watch: updateWebhookURL called with: \(newURL)")
        print("📝 Watch: Current webhook URL: \(WatchConstants.API.webhookURL)")
    }
    
    func checkConnectivity() {
        // Don't do connectivity checks - let actual requests fail if needed
        // This allows the watch to work even when initial connectivity checks fail
        print("🌐 Watch: Skipping connectivity check, assuming connected")
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }
    
    func processVoiceCommand(audioData: Data, completion: @escaping (Result<VoiceResponse, Error>) -> Void) {
        // Always try to process, don't check isConnected
        isProcessing = true
        
        // Try new backend API first, fall back to legacy if needed
        print("🔍 Watch: Processing - isAuthenticated: \(isAuthenticated)")
        if isAuthenticated {
            sendAudioToNewAPI(audioData, completion: completion)
        } else {
            // For now, try the new API without authentication to test
            print("🔧 Watch: Trying new API without authentication for testing")
            sendAudioToNewAPI(audioData, completion: completion)
        }
    }
    
    private func sendAudioToNewAPI(_ audioData: Data, completion: @escaping (Result<VoiceResponse, Error>) -> Void) {
        // Use the same endpoint as iPhone app
        let endpoint = "/api/voice/process-audio"
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(VoiceAssistantError.networkError))
            return
        }
        
        print("🌐 Watch: Sending audio to new API: \(audioData.count) bytes")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add authentication header
        if let accessToken = accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("🔐 Watch: Using access token: \(accessToken.prefix(20))...")
        } else {
            print("⚠️ Watch: No access token available, proceeding without authentication")
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add sessionId field (matching iPhone format exactly)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"sessionId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(WatchConstants.getCurrentSessionId())\r\n".data(using: .utf8)!)
        
        // Add audio file (use correct WAV format as that's what's actually recorded)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isProcessing = false
            }
            
            if let error = error {
                print("❌ Watch: New API error: \(error)")
                DispatchQueue.main.async {
                    self?.lastError = error
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Watch: Invalid response type")
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.networkError))
                }
                return
            }
            
            print("📡 Watch: New API HTTP Status: \(httpResponse.statusCode)")
            
            guard 200...299 ~= httpResponse.statusCode else {
                print("❌ Watch: New API HTTP Error: \(httpResponse.statusCode)")
                
                // For 401 errors, clear authentication and retry
                if httpResponse.statusCode == 401 {
                    print("🔧 Watch: Authentication failed, clearing tokens")
                    self?.clearTokens()
                    DispatchQueue.main.async {
                        completion(.failure(VoiceAssistantError.networkError))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(VoiceAssistantError.networkError))
                    }
                }
                return
            }
            
            guard let data = data else {
                print("❌ Watch: No response data from new API")
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.invalidResponse))
                }
                return
            }
            
            print("📥 Watch: New API response data size: \(data.count) bytes")
            self?.parseNewAPIResponse(data, completion: completion)
        }.resume()
    }
    
    private func sendAudioToLegacyAPI(_ audioData: Data, completion: @escaping (Result<VoiceResponse, Error>) -> Void) {
        guard let url = URL(string: WatchConstants.API.webhookURL) else {
            completion(.failure(VoiceAssistantError.networkError))
            return
        }
        
        print("🌐 Watch: Sending audio data to legacy API: \(audioData.count) bytes")
        
        // Create a multipart form data request with the audio file
        let boundary = UUID().uuidString
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create multipart form data
        var bodyData = Data()
        
        // Add audio file
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        bodyData.append(audioData)
        bodyData.append("\r\n".data(using: .utf8)!)
        
        // Add session ID
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"sessionId\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append(WatchConstants.getCurrentSessionId().data(using: .utf8)!)
        bodyData.append("\r\n".data(using: .utf8)!)
        
        // Add voice ID
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"voiceId\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append(WatchConstants.API.defaultVoiceId.data(using: .utf8)!)
        bodyData.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        urlRequest.httpBody = bodyData
        print("📦 Watch: Legacy API request body size: \(bodyData.count) bytes")
        
        session.dataTask(with: urlRequest) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isProcessing = false
            }
            
            if let error = error {
                print("❌ Watch: Legacy API network error: \(error)")
                DispatchQueue.main.async {
                    self?.lastError = error
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Watch: Invalid response type")
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.networkError))
                }
                return
            }
            
            print("📡 Watch: Legacy API HTTP Status: \(httpResponse.statusCode)")
            
            guard 200...299 ~= httpResponse.statusCode else {
                print("❌ Watch: Legacy API HTTP Error: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.networkError))
                }
                return
            }
            
            guard let data = data else {
                print("❌ Watch: No response data from legacy API")
                DispatchQueue.main.async {
                    completion(.failure(VoiceAssistantError.invalidResponse))
                }
                return
            }
            
            print("📥 Watch: Legacy API response data size: \(data.count) bytes")
            self?.parseLegacyResponse(data, completion: completion)
        }.resume()
    }
    
    private func parseNewAPIResponse(_ data: Data, completion: @escaping (Result<VoiceResponse, Error>) -> Void) {
        do {
            let backendResponse = try JSONDecoder().decode(BackendVoiceResponse.self, from: data)
            
            let response = VoiceResponse(
                text: backendResponse.response ?? "",
                success: backendResponse.success,
                audioBase64: backendResponse.audioResponse?.audioBase64
            )
            
            DispatchQueue.main.async {
                completion(.success(response))
            }
        } catch {
            print("❌ Watch: Failed to parse new API response: \(error)")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
    
    private func parseLegacyResponse(_ data: Data, completion: @escaping (Result<VoiceResponse, Error>) -> Void) {
        // Check if it's JSON first
        if let jsonString = String(data: data, encoding: .utf8),
           jsonString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
            print("📋 Watch: Detected JSON response")
            parseJSONResponse(data, completion: completion)
        } else {
            print("🎵 Watch: Detected binary audio response")
            parseBinaryAudioResponse(data, completion: completion)
        }
    }
    
    private func parseJSONResponse(_ data: Data, completion: @escaping (Result<VoiceResponse, Error>) -> Void) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📋 Watch: Parsed JSON: \(json)")
                
                // Check for n8n binary response format
                if let binary = json["binary"] as? [String: Any],
                   let binaryData = binary["data"] as? [String: Any],
                   let audioBase64 = binaryData["data"] as? String {
                    
                    print("✅ Watch: Found n8n binary format")
                    
                    // Extract text from various possible locations
                    let responseText = json["text"] as? String ?? 
                                     json["responseText"] as? String ?? 
                                     json["output"] as? String ?? 
                                     json["response"] as? String ?? 
                                     ""
                    
                    print("📝 Watch: Extracted text from n8n response: '\(responseText)'")
                    
                    let response = VoiceResponse(
                        text: responseText,
                        success: json["success"] as? Bool ?? true,
                        audioBase64: audioBase64
                    )
                    
                    DispatchQueue.main.async {
                        completion(.success(response))
                    }
                } else {
                    // Try standard VoiceResponse format
                    let response = try JSONDecoder().decode(VoiceResponse.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(response))
                    }
                }
            }
        } catch {
            print("❌ Watch: JSON Parse error: \(error)")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
    
    private func parseBinaryAudioResponse(_ data: Data, completion: @escaping (Result<VoiceResponse, Error>) -> Void) {
        print("🎵 Watch: Processing binary audio response (\(data.count) bytes)")
        
        let audioBase64 = data.base64EncodedString()
        print("🎵 Watch: Created base64 audio string: \(audioBase64.prefix(50))...")
        
        let response = VoiceResponse(
            text: "", // Empty text since n8n only returns audio
            success: true,
            audioBase64: audioBase64
        )
        
        DispatchQueue.main.async {
            completion(.success(response))
        }
    }
    
}

