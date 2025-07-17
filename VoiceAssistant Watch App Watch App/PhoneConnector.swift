//
//  PhoneConnector.swift
//  VoiceAssistant
//
//  Created by Amit Störkel on 16.07.25.
//
import Foundation
import WatchConnectivity
import WatchKit

class PhoneConnector: NSObject, ObservableObject {
    
    static let shared = PhoneConnector()
    
    private var session: WCSession?
    
    @Published var isConnected: Bool = false
    @Published var status: VoiceAssistantStatus = .idle
    @Published var lastResponse: VoiceResponse?
    @Published var errorMessage: String?
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported on this device")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
    }
    
    func activate() {
        session?.activate()
    }
    
    func sendAudioForTranscription(_ audioData: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let session = session, session.isReachable else {
            completion(.failure(VoiceAssistantError.watchConnectivityFailed))
            return
        }
        
        let message: [String: Any] = [
            "type": "transcriptionRequest",
            "sessionId": Constants.getCurrentSessionId(),
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessageData(audioData, replyHandler: { responseData in
            DispatchQueue.main.async {
                completion(.success(()))
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        })
    }
    
    func sendStatusUpdate(_ status: VoiceAssistantStatus) {
        guard let session = session, session.isReachable else { return }
        
        let message: [String: Any] = [
            "type": "status",
            "status": status.rawValue,
            "sessionId": Constants.getCurrentSessionId(),
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("Failed to send status update: \(error)")
        })
        
        DispatchQueue.main.async {
            self.status = status
        }
    }
    
    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let messageType = message["type"] as? String else {
            print("Invalid message type received")
            return
        }
        
        switch messageType {
        case "voiceResponse":
            handleVoiceResponse(message)
        case "error":
            handleError(message)
        case "status":
            handleStatusUpdate(message)
        default:
            print("Unhandled message type: \(messageType)")
        }
    }
    
    private func handleVoiceResponse(_ message: [String: Any]) {
        guard let responseData = message["response"] as? Data else {
            print("Invalid voice response data")
            return
        }
        
        do {
            let response = try JSONDecoder().decode(VoiceResponse.self, from: responseData)
            
            DispatchQueue.main.async {
                self.lastResponse = response
                self.status = .playing
                
                // Provide haptic feedback
                WKInterfaceDevice.current().play(.success)
            }
        } catch {
            print("Failed to decode voice response: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to decode response"
                self.status = .error
            }
        }
    }
    
    private func handleError(_ message: [String: Any]) {
        let errorMsg = message["message"] as? String ?? "Unknown error"
        
        DispatchQueue.main.async {
            self.errorMessage = errorMsg
            self.status = .error
            
            // Provide haptic feedback
            WKInterfaceDevice.current().play(.failure)
        }
    }
    
    private func handleStatusUpdate(_ message: [String: Any]) {
        guard let statusString = message["status"] as? String,
              let newStatus = VoiceAssistantStatus(rawValue: statusString) else {
            print("Invalid status update")
            return
        }
        
        DispatchQueue.main.async {
            self.status = newStatus
        }
    }
}

extension PhoneConnector: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = (activationState == .activated) && session.isReachable
        }
        
        if let error = error {
            print("WCSession activation failed: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to connect to iPhone"
            }
        } else {
            print("WCSession activated successfully")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
        }
        
        if !session.isReachable {
            DispatchQueue.main.async {
                self.errorMessage = "iPhone not reachable"
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleIncomingMessage(message)
        
        replyHandler([
            "status": "received",
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        print("Received data message: \(messageData.count) bytes")
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        print("Received data message with reply handler: \(messageData.count) bytes")
        
        let response = "received".data(using: .utf8) ?? Data()
        replyHandler(response)
    }
}
