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
        
        // Use polling transport for reliable connection
        connectWithPolling(accessToken: accessToken)
    }
    
    private var sessionId: String?
    private var pollingTimer: Timer?
    
    private func connectWithPolling(accessToken: String) {
        // Socket.IO handshake URL with Engine.IO v4
        let handshakeURL = "\(Constants.API.baseURL)/socket.io/?EIO=4&transport=polling"
        guard let url = URL(string: handshakeURL) else {
            print("❌ WebSocket: Invalid handshake URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        print("🔌 WebSocket: Connecting with polling transport to \(handshakeURL)")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ WebSocket: Polling connection error: \(error)")
                self?.handleConnectionError(error)
                return
            }
            
            guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                print("❌ WebSocket: Invalid polling response")
                return
            }
            
            print("📥 WebSocket: Polling handshake response: \(responseString)")
            self?.handlePollingHandshake(responseString, accessToken: accessToken)
        }
        
        task.resume()
    }
    
    private func handlePollingHandshake(_ response: String, accessToken: String) {
        guard response.hasPrefix("0{") else {
            print("❌ WebSocket: Invalid handshake response format")
            return
        }
        
        let jsonString = String(response.dropFirst())
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sid = json["sid"] as? String else {
            print("❌ WebSocket: Failed to parse session ID from handshake")
            return
        }
        
        self.sessionId = sid
        print("✅ WebSocket: Connected with polling, sid: \(sid)")
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionRetryCount = 0
            self.onConnectionStatusChanged?(true)
        }
        
        // Send Socket.IO connect message
        sendPollingMessage("40")
        
        // Start polling for incoming messages
        startPolling(accessToken: accessToken)
        
        // Send authentication
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.authenticate()
        }
    }
    
    private func startPolling(accessToken: String) {
        guard let sessionId = sessionId else { return }
        
        // Poll for messages every 2 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollForMessages(accessToken: accessToken, sessionId: sessionId)
        }
    }
    
    private func pollForMessages(accessToken: String, sessionId: String) {
        let pollURL = "\(Constants.API.baseURL)/socket.io/?EIO=4&transport=polling&sid=\(sessionId)"
        guard let url = URL(string: pollURL) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ WebSocket: Polling error: \(error)")
                return
            }
            
            guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                return
            }
            
            if !responseString.isEmpty {
                print("📥 WebSocket: Polling received: \(responseString)")
                self?.parsePollingMessage(responseString)
            }
        }
        
        task.resume()
    }
    
    private func parsePollingMessage(_ message: String) {
        // Handle multiple messages in one response
        var remaining = message
        while !remaining.isEmpty {
            // Check for length-prefixed messages
            if let colonIndex = remaining.firstIndex(of: ":") {
                let lengthStr = String(remaining[..<colonIndex])
                if let length = Int(lengthStr) {
                    let startIndex = remaining.index(after: colonIndex)
                    let endIndex = remaining.index(startIndex, offsetBy: length)
                    let messageContent = String(remaining[startIndex..<endIndex])
                    parseMessage(messageContent)
                    remaining = String(remaining[endIndex...])
                } else {
                    break
                }
            } else {
                parseMessage(remaining)
                break
            }
        }
    }
    
    private func sendPollingMessage(_ message: String) {
        guard let sessionId = sessionId else {
            print("❌ WebSocket: No session ID for polling message")
            return
        }
        
        let postURL = "\(Constants.API.baseURL)/socket.io/?EIO=4&transport=polling&sid=\(sessionId)"
        guard let url = URL(string: postURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        
        // Format message with length prefix
        let formattedMessage = "\(message.count):\(message)"
        request.httpBody = formattedMessage.data(using: .utf8)
        
        print("📤 WebSocket: Sending polling message: \(formattedMessage)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ WebSocket: Failed to send polling message: \(error)")
            }
        }
        
        task.resume()
    }
    
    private func performSocketIOHandshake(accessToken: String) {
        // Socket.IO handshake URL with Engine.IO v4
        let handshakeURL = "\(Constants.API.baseURL)/socket.io/?EIO=4&transport=polling"
        guard let url = URL(string: handshakeURL) else {
            print("❌ WebSocket: Invalid handshake URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        print("🔌 WebSocket: Performing Socket.IO handshake at \(handshakeURL)")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ WebSocket: Handshake error: \(error)")
                self?.handleConnectionError(error)
                return
            }
            
            guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                print("❌ WebSocket: Invalid handshake response")
                return
            }
            
            print("📥 WebSocket: Handshake response: \(responseString)")
            self?.parseHandshakeResponse(responseString, accessToken: accessToken)
        }
        
        task.resume()
    }
    
    private func parseHandshakeResponse(_ response: String, accessToken: String) {
        // Socket.IO response format: "0{\"sid\":\"...\",\"upgrades\":[\"websocket\"],\"pingInterval\":25000,\"pingTimeout\":20000,\"maxPayload\":1000000}"
        guard response.hasPrefix("0{") else {
            print("❌ WebSocket: Invalid handshake response format")
            return
        }
        
        let jsonString = String(response.dropFirst())
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sid = json["sid"] as? String else {
            print("❌ WebSocket: Failed to parse session ID from handshake")
            return
        }
        
        print("✅ WebSocket: Handshake successful, sid: \(sid)")
        
        // Now upgrade to WebSocket using the session ID
        upgradeToWebSocket(sid: sid, accessToken: accessToken)
    }
    
    private func upgradeToWebSocket(sid: String, accessToken: String) {
        // Socket.IO WebSocket upgrade URL
        let wsURL = "\(Constants.API.websocketURL)?EIO=4&transport=websocket&sid=\(sid)"
        guard let url = URL(string: wsURL) else {
            print("❌ WebSocket: Invalid WebSocket upgrade URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        print("🔌 WebSocket: Upgrading to WebSocket: \(wsURL)")
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start listening for messages
        receive()
        
        // Send probe message for WebSocket upgrade confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.sendProbeMessage()
        }
        
        // Send authentication after WebSocket upgrade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.authenticate()
        }
    }
    
    private func sendProbeMessage() {
        webSocketTask?.send(.string("2probe")) { error in
            if let error = error {
                print("❌ WebSocket: Failed to send probe: \(error)")
            } else {
                print("📤 WebSocket: Sent probe message")
            }
        }
    }
    
    func disconnect() {
        print("🔌 WebSocket: Disconnecting")
        pollingTimer?.invalidate()
        pollingTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        sessionId = nil
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
    
    // Legacy WebSocket receive method - no longer used with polling
    private func receive() {
        // This method is now handled by polling
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
        // Handle Socket.IO/Engine.IO protocol messages
        if text.isEmpty {
            return
        }
        
        let firstChar = text.first!
        let payload = String(text.dropFirst())
        
        switch firstChar {
        case "0": // open packet
            print("📥 WebSocket: Received open packet")
            
        case "1": // close packet
            print("📥 WebSocket: Received close packet")
            
        case "2": // ping packet
            print("📥 WebSocket: Received ping, sending pong")
            webSocketTask?.send(.string("3")) { _ in }
            
        case "3": // pong packet
            print("📥 WebSocket: Received pong")
            
        case "4": // message packet
            if payload.isEmpty {
                return
            }
            
            let socketIOType = payload.first!
            let socketIOPayload = String(payload.dropFirst())
            
            switch socketIOType {
            case "0": // connect
                print("✅ WebSocket: Socket.IO connected")
                DispatchQueue.main.async {
                    self.isConnected = true
                    self.connectionRetryCount = 0
                    self.onConnectionStatusChanged?(true)
                }
                // Send authentication after connection
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.authenticate()
                }
                
            case "1": // disconnect
                print("❌ WebSocket: Socket.IO disconnected")
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.onConnectionStatusChanged?(false)
                }
                
            case "2": // event
                parseSocketIOEvent(socketIOPayload)
                
            default:
                print("❓ WebSocket: Unknown Socket.IO message type: \(socketIOType)")
            }
            
        case "5": // upgrade packet
            print("📥 WebSocket: Received upgrade confirmation")
            
        case "6": // noop packet
            print("📥 WebSocket: Received noop")
            
        default:
            print("❓ WebSocket: Unknown Engine.IO packet type: \(firstChar)")
        }
    }
    
    private func parseSocketIOEvent(_ payload: String) {
        guard let data = payload.data(using: .utf8) else {
            print("❌ WebSocket: Failed to convert Socket.IO payload to data")
            return
        }
        
        do {
            guard let array = try JSONSerialization.jsonObject(with: data) as? [Any],
                  array.count >= 2,
                  let eventType = array[0] as? String,
                  let eventData = array[1] as? [String: Any] else {
                print("❌ WebSocket: Invalid Socket.IO event format")
                return
            }
            
            handleEvent(eventType, data: eventData)
        } catch {
            print("❌ WebSocket: Failed to parse Socket.IO event: \(error)")
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
                text: backendResponse.response?.text ?? backendResponse.text ?? "",
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
            
            // Format as Socket.IO event message: "42" + JSON array
            let socketIOMessage = "42" + messageString
            
            print("📤 WebSocket: Sending message: \(socketIOMessage)")
            
            webSocketTask.send(.string(socketIOMessage)) { error in
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
        
        // Socket.IO event format: ["event_name", data]
        let authData = [
            "type": "authenticate",
            "token": accessToken
        ]
        
        let authEvent = ["authenticate", authData] as [Any]
        
        sendSocketIOEvent(authEvent)
    }
    
    private func sendSocketIOEvent(_ event: [Any]) {
        guard isConnected else {
            print("❌ WebSocket: No active connection")
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: event)
            let messageString = String(data: jsonData, encoding: .utf8) ?? ""
            
            // Format as Socket.IO event message: "42" + JSON array
            let socketIOMessage = "42" + messageString
            
            print("📤 WebSocket: Sending Socket.IO event: \(socketIOMessage)")
            
            sendPollingMessage(socketIOMessage)
        } catch {
            print("❌ WebSocket: Failed to serialize Socket.IO event: \(error)")
        }
    }
    
    // MARK: - Voice Commands
    
    func sendVoiceCommand(_ request: VoiceRequest) {
        guard isConnected else {
            print("❌ WebSocket: Not connected, cannot send voice command")
            return
        }
        
        let messageData: [String: Any] = [
            "type": "voice-command",
            "text": request.text,
            "sessionId": request.context.sessionId,
            "metadata": request.context.metadata ?? [:],
            "platform": request.platform
        ]
        
        let event = ["voice-command", messageData] as [Any]
        sendSocketIOEvent(event)
    }
    
    func sendVoiceStream(audioData: Data, sessionId: String, isEnd: Bool = false) {
        guard isConnected else {
            print("❌ WebSocket: Not connected, cannot send voice stream")
            return
        }
        
        let audioBase64 = audioData.base64EncodedString()
        let messageData: [String: Any] = [
            "type": isEnd ? "voice-stream-end" : "voice-stream-chunk",
            "sessionId": sessionId,
            "audioData": audioBase64
        ]
        
        let eventName = isEnd ? "voice-stream-end" : "voice-stream-chunk"
        let event = [eventName, messageData] as [Any]
        sendSocketIOEvent(event)
    }
    
    func getConversationHistory(limit: Int = 20) {
        guard isConnected else {
            print("❌ WebSocket: Not connected, cannot get conversation history")
            return
        }
        
        let messageData: [String: Any] = [
            "type": "get-conversation-history",
            "limit": limit
        ]
        
        let event = ["get-conversation-history", messageData] as [Any]
        sendSocketIOEvent(event)
    }
    
    func clearConversationHistory() {
        guard isConnected else {
            print("❌ WebSocket: Not connected, cannot clear conversation history")
            return
        }
        
        let messageData: [String: Any] = [
            "type": "clear-conversation-history"
        ]
        
        let event = ["clear-conversation-history", messageData] as [Any]
        sendSocketIOEvent(event)
    }
    
    func ping() {
        guard isConnected else {
            return
        }
        
        let messageData: [String: Any] = [
            "type": "ping"
        ]
        
        let event = ["ping", messageData] as [Any]
        sendSocketIOEvent(event)
    }
    
    // MARK: - Health Check
    
    func startHealthCheck() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.ping()
        }
    }
}