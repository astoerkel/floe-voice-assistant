//
//  WatchConnector.swift
//  VoiceAssistant
//
//  Created by Amit Störkel on 16.07.25.
//

import Foundation
import WatchConnectivity

class WatchConnector: NSObject, ObservableObject {
    static let shared = WatchConnector()
    
    @Published var isReachable = false
    private var session: WCSession
    
    override init() {
        self.session = WCSession.default
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    func sendTranscribedText(_ text: String, response: String, audioData: Data?) {
        guard session.isReachable else { return }
        
        var message: [String: Any] = [
            "transcribedText": text,
            "responseText": response
        ]
        
        if let audioData = audioData {
            message["audioData"] = audioData
        }
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending message to watch: \(error)")
        }
    }
}

extension WatchConnector: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let audioData = message["audioData"] as? Data {
            // Process audio from watch
            Task {
                await processAudioFromWatch(audioData, replyHandler: replyHandler)
            }
        }
    }
    
    private func processAudioFromWatch(_ audioData: Data, replyHandler: @escaping ([String : Any]) -> Void) async {
        do {
            // 1. Transcribe audio
            let speechRecognizer = SpeechRecognizer()
            let transcribedText = try await speechRecognizer.transcribeAudio(audioData)
            
            // 2. Send to API
            let (responseText, responseAudio) = try await APIClient.shared.sendVoiceCommand(transcribedText)
            
            // 3. Send response back to watch
            var response: [String: Any] = [
                "status": "success",
                "transcribedText": transcribedText,
                "responseText": responseText
            ]
            
            if let audioData = responseAudio {
                response["audioData"] = audioData
            }
            
            replyHandler(response)
            
        } catch {
            replyHandler([
                "status": "error",
                "error": error.localizedDescription
            ])
        }
    }
}
