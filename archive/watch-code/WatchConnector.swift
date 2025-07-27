import Foundation
import WatchConnectivity

class WatchConnector: NSObject, ObservableObject {
    static let shared = WatchConnector()
    
    @Published var isConnected = false
    @Published var currentStatus: VoiceAssistantStatus = .idle
    
    var onAudioReceived: ((Data) -> Void)?
    var onStatusUpdate: ((VoiceAssistantStatus) -> Void)?
    
    private var session: WCSession?
    
    override init() {
        print("📱 iPhone WatchConnector: Initializing...")
        super.init()
        
        if WCSession.isSupported() {
            print("📱 iPhone WatchConnector: WCSession is supported")
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            print("📱 iPhone WatchConnector: Session activation requested")
        } else {
            print("❌ iPhone WatchConnector: WCSession NOT supported")
        }
    }
    
    func sendVoiceResponse(_ response: VoiceResponse) {
        // Send as a new message, not a reply
        guard let session = session, session.isReachable else {
            print("❌ iPhone: Cannot send response - Watch not reachable")
            return
        }
        
        print("📤 iPhone WatchConnector: Sending response to Watch")
        print("📤 iPhone WatchConnector: Response text: '\(response.text)'")
        print("📤 iPhone WatchConnector: Response success: \(response.success)")
        print("📤 iPhone WatchConnector: AudioBase64 length: \(response.audioBase64?.count ?? 0)")
        
        let responseMessage: [String: Any] = [
            "type": "voiceResponse",
            "success": true,
            "text": response.text,
            "audioBase64": response.audioBase64 ?? ""
        ]
        
        print("📦 iPhone WatchConnector: Sending voice response message")
        
        // Send as a regular message (no reply expected)
        session.sendMessage(responseMessage, replyHandler: nil, errorHandler: { error in
            print("❌ iPhone: Failed to send response to Watch: \(error.localizedDescription)")
        })
    }
    
    func sendError(_ errorMessage: String) {
        // Send as a new message, not a reply
        guard let session = session, session.isReachable else {
            print("❌ iPhone: Cannot send error - Watch not reachable")
            return
        }
        
        print("📤 iPhone: Sending error to Watch: \(errorMessage)")
        
        let errorMsg: [String: Any] = [
            "type": "error",
            "message": errorMessage
        ]
        
        session.sendMessage(errorMsg, replyHandler: nil, errorHandler: { error in
            print("❌ iPhone: Failed to send error to Watch: \(error.localizedDescription)")
        })
    }
    
    func updateStatus(_ status: VoiceAssistantStatus) {
        currentStatus = status
        onStatusUpdate?(status)
        
        // Don't send status updates to Watch during processing
        // The Watch will update based on the final response
    }
}

// MARK: - WCSessionDelegate
extension WatchConnector: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            print("📱 iPhone WatchConnector: Activation completed")
            print("📱 iPhone WatchConnector: State: \(activationState.rawValue)")
            print("📱 iPhone WatchConnector: isPaired: \(session.isPaired)")
            print("📱 iPhone WatchConnector: isWatchAppInstalled: \(session.isWatchAppInstalled)")
            print("📱 iPhone WatchConnector: isReachable: \(session.isReachable)")
            
            switch activationState {
            case .activated:
                print("✅ iPhone: WCSession activated")
                self.isConnected = session.isPaired && session.isWatchAppInstalled
            case .inactive:
                print("⚠️ iPhone: WCSession inactive")
                self.isConnected = false
            case .notActivated:
                print("❌ iPhone: WCSession not activated")
                self.isConnected = false
            @unknown default:
                self.isConnected = false
            }
            
            print("📱 iPhone WatchConnector: Final isConnected: \(self.isConnected)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("🔄 iPhone: Reachability changed - Watch reachable: \(session.isReachable)")
            self.isConnected = session.isReachable && session.isPaired && session.isWatchAppInstalled
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("📥 iPhone WatchConnector: didReceiveMessage called")
        print("📥 iPhone WatchConnector: Message content: \(message)")
        
        DispatchQueue.main.async {
            print("📥 iPhone: Received message from Watch")
            
            if let type = message["type"] as? String {
                print("📥 iPhone: Message type: \(type)")
                switch type {
                case "audioData":
                    if let audioData = message["audio"] as? Data {
                        print("🎵 iPhone: Received audio data (\(audioData.count) bytes)")
                        
                        // Send immediate acknowledgment
                        replyHandler(["acknowledged": true])
                        print("✅ iPhone: Sent acknowledgment to Watch")
                        
                        // Process the audio - response will be sent as a new message
                        self.onAudioReceived?(audioData)
                        
                    } else {
                        print("❌ iPhone: No audio data in message")
                        replyHandler(["success": false, "error": "No audio data"])
                    }
                default:
                    print("❌ iPhone: Unknown message type: \(type)")
                    replyHandler(["success": false, "error": "Unknown message type"])
                }
            } else {
                print("❌ iPhone: No message type in message")
                replyHandler(["success": false, "error": "No message type"])
            }
        }
    }
}
