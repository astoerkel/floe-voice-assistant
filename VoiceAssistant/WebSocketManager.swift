//
//  WebSocketManager.swift
//  VoiceAssistant
//
//  Created by Claude on 17.07.25.
//

import Foundation
import Network

class WebSocketManager: NSObject, ObservableObject {
    static let shared = WebSocketManager()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private let baseURL: String
    
    @Published var isConnected = false
    @Published var lastError: Error?
    
    // Callback handlers
    var onAuthenticated: (() -> Void)?
    var onAuthError: ((String) -> Void)?
    var onVoiceResponse: ((VoiceResponse) -> Void)?
    var onVoiceError: ((String) -> Void)?
    var onConnectionStatusChanged: ((Bool) -> Void)?
    
    private var accessToken: String?
    private var connectionRetryCount = 0
    private let maxRetries = 3
    
    override init() {
        self.baseURL = Constants.API.baseURL
        self.session = URLSession(configuration: .default)
        super.init()
    }
    
    // MARK: - Connection Management
    
    func connect(accessToken: String) {
        self.accessToken = accessToken
        connectionRetryCount = 0
        connectInternal()
    }
    
    private func connectInternal() {
        guard let accessToken = accessToken else {
            print("❌ WebSocket: No access token available")
            return
        }
        
        // Convert HTTP URL to WebSocket URL
        let wsURL = baseURL.replacingOccurrences(of: "https://", with: "wss://")
        guard let url = URL(string: wsURL) else {
            print("❌ WebSocket: Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        print("🔌 WebSocket: Connecting to \(wsURL)")
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start listening for messages
        receive()
        
        // Send authentication after connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.authenticate()
        }
    }
    
    func disconnect() {
        print("🔌 WebSocket: Disconnecting")
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.onConnectionStatusChanged?(false)
        }
    }
    
    private func reconnect() {
        guard connectionRetryCount < maxRetries else {
            print("❌ WebSocket: Max retries reached")
            return
        }
        
        connectionRetryCount += 1
        print("🔄 WebSocket: Reconnecting (attempt \(connectionRetryCount))")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(connectionRetryCount) * 2) {
            self.connectInternal()
        }
    }
    
    // MARK: - Message Handling
    
    private func receive() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                // Continue listening
                self?.receive()
            case .failure(let error):
                print("❌ WebSocket: Receive error: \(error)")
                self?.handleConnectionError(error)
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            print("📥 WebSocket: Received text message: \(text)")
            parseMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                print("📥 WebSocket: Received data message: \(text)")
                parseMessage(text)
            }
        @unknown default:
            print("❌ WebSocket: Unknown message type")
        }
    }
    
    private func parseMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            print("❌ WebSocket: Failed to convert message to data")
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let eventType = json?["type"] as? String else {
                print("❌ WebSocket: No event type in message")
                return
            }
            
            handleEvent(eventType, data: json ?? [:])
        } catch {
            print("❌ WebSocket: Failed to parse message: \(error)")
        }
    }
    
    private func handleEvent(_ eventType: String, data: [String: Any]) {
        switch eventType {
        case "authenticated":
            print("✅ WebSocket: Authentication successful")
            DispatchQueue.main.async {
                self.isConnected = true
                self.connectionRetryCount = 0
                self.onAuthenticated?()
                self.onConnectionStatusChanged?(true)
            }
            
        case "auth-error":
            let errorMessage = data["message"] as? String ?? "Authentication failed"
            print("❌ WebSocket: Authentication error: \(errorMessage)")
            DispatchQueue.main.async {
                self.lastError = VoiceAssistantError.webSocketAuthenticationFailed
                self.onAuthError?(errorMessage)
            }
            
        case "voice-response":
            handleVoiceResponse(data)
            
        case "voice-error":
            let errorMessage = data["message"] as? String ?? "Voice processing failed"
            print("❌ WebSocket: Voice error: \(errorMessage)")
            DispatchQueue.main.async {
                self.lastError = VoiceAssistantError.voiceProcessingFailed
                self.onVoiceError?(errorMessage)
            }
            
        case "pong":
            print("🏓 WebSocket: Received pong")
            
        default:
            print("❓ WebSocket: Unknown event type: \(eventType)")
        }
    }
    
    private func handleVoiceResponse(_ data: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let backendResponse = try JSONDecoder().decode(BackendVoiceResponse.self, from: jsonData)
            
            let response = VoiceResponse(
                text: backendResponse.response ?? "",
                success: backendResponse.success,
                audioBase64: backendResponse.audioResponse?.audioBase64
            )
            
            DispatchQueue.main.async {
                self.onVoiceResponse?(response)
            }
        } catch {
            print("❌ WebSocket: Failed to decode voice response: \(error)")
        }
    }
    
    private func handleConnectionError(_ error: Error) {
        print("❌ WebSocket: Connection error: \(error)")
        
        let mappedError = mapConnectionError(error)
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.lastError = mappedError
            self.onConnectionStatusChanged?(false)
        }
        
        // Attempt to reconnect for recoverable errors
        if shouldRetryConnection(for: mappedError) {
            reconnect()
        } else {
            print("❌ WebSocket: Connection error not recoverable, not retrying")
        }
    }
    
    private func mapConnectionError(_ error: Error) -> VoiceAssistantError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError
            case .timedOut:
                return .webSocketConnectionFailed
            case .userAuthenticationRequired:
                return .authenticationRequired
            case .secureConnectionFailed:
                return .webSocketAuthenticationFailed
            default:
                return .webSocketConnectionFailed
            }
        }
        
        return .unknownError(error.localizedDescription)
    }
    
    private func shouldRetryConnection(for error: VoiceAssistantError) -> Bool {
        switch error {
        case .networkError, .webSocketConnectionFailed, .backendUnavailable:
            return true
        case .authenticationRequired, .authenticationFailed, .webSocketAuthenticationFailed:
            return false
        default:
            return true
        }
    }
    
    // MARK: - Message Sending
    
    private func sendMessage(_ message: [String: Any]) {
        guard let webSocketTask = webSocketTask else {
            print("❌ WebSocket: No active connection")
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message)
            let messageString = String(data: jsonData, encoding: .utf8) ?? ""
            
            print("📤 WebSocket: Sending message: \(messageString)")
            
            webSocketTask.send(.string(messageString)) { error in
                if let error = error {
                    print("❌ WebSocket: Send error: \(error)")
                }
            }
        } catch {
            print("❌ WebSocket: Failed to serialize message: \(error)")
        }
    }
    
    private func authenticate() {
        guard let accessToken = accessToken else {
            print("❌ WebSocket: No access token for authentication")
            return
        }
        
        let authMessage = [
            "type": "authenticate",
            "token": accessToken
        ]
        
        sendMessage(authMessage)
    }
    
    // MARK: - Voice Commands
    
    func sendVoiceCommand(_ request: VoiceRequest) {
        guard isConnected else {
            print("❌ WebSocket: Not connected, cannot send voice command")
            return
        }
        
        let message: [String: Any] = [
            "type": "voice-command",
            "text": request.text,
            "sessionId": request.sessionId,
            "metadata": request.metadata ?? [:],
            "generateAudio": request.generateAudio
        ]
        
        sendMessage(message)
    }
    
    func sendVoiceStream(audioData: Data, sessionId: String, isEnd: Bool = false) {
        guard isConnected else {
            print("❌ WebSocket: Not connected, cannot send voice stream")
            return
        }
        
        let audioBase64 = audioData.base64EncodedString()
        let message: [String: Any] = [
            "type": isEnd ? "voice-stream-end" : "voice-stream-chunk",
            "sessionId": sessionId,
            "audioData": audioBase64
        ]
        
        sendMessage(message)
    }
    
    func getConversationHistory(limit: Int = 20) {
        guard isConnected else {
            print("❌ WebSocket: Not connected, cannot get conversation history")
            return
        }
        
        let message: [String: Any] = [
            "type": "get-conversation-history",
            "limit": limit
        ]
        
        sendMessage(message)
    }
    
    func clearConversationHistory() {
        guard isConnected else {
            print("❌ WebSocket: Not connected, cannot clear conversation history")
            return
        }
        
        let message: [String: Any] = [
            "type": "clear-conversation-history"
        ]
        
        sendMessage(message)
    }
    
    func ping() {
        guard isConnected else {
            return
        }
        
        let message: [String: Any] = [
            "type": "ping"
        ]
        
        sendMessage(message)
    }
    
    // MARK: - Health Check
    
    func startHealthCheck() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.ping()
        }
    }
}