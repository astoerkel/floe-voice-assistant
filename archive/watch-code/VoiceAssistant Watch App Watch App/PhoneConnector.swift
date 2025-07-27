import Foundation
import WatchConnectivity
import AVFoundation

class PhoneConnector: NSObject, ObservableObject {
    static let shared = PhoneConnector()
    
    var session: WCSession?
    private var audioPlayer: AVAudioPlayer?
    
    @Published var isConnected: Bool = false
    @Published var currentStatus: VoiceAssistantStatus = .idle
    @Published var lastResponse: VoiceResponse?
    @Published var errorMessage: String?
    
    override init() {
        print("📱 Watch PhoneConnector: Initializing...")
        super.init()
        
        if WCSession.isSupported() {
            print("📱 Watch PhoneConnector: WCSession is supported")
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            print("📱 Watch PhoneConnector: Session activation requested")
        } else {
            print("❌ Watch PhoneConnector: WCSession NOT supported")
        }
    }
    
    func sendAudioData(_ audioData: Data) {
        guard let session = session, session.isReachable else {
            print("❌ Watch: iPhone not reachable, trying direct processing...")
            // Try to process directly if iPhone is not available
            processAudioDirectly(audioData)
            return
        }
        
        print("📤 Watch: Sending audio data (\(audioData.count) bytes)")
        updateStatus(.transcribing)
        
        let message: [String: Any] = [
            "type": "audioData",
            "audio": audioData,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        print("📤 Watch: Message prepared, calling sendMessage...")
        print("📤 Watch: Session reachable: \(session.isReachable)")
        
        // Use sendMessage WITHOUT expecting immediate reply (just acknowledgment)
        session.sendMessage(message, replyHandler: { response in
            print("📥 Watch: Acknowledgment received from iPhone")
            // iPhone will send the actual response as a separate message later
        }, errorHandler: { error in
            print("❌ Watch: Error handler called with error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                print("❌ Watch: Failed to send audio: \(error.localizedDescription)")
                self.updateStatus(.error)
                self.errorMessage = "Failed to send audio"
            }
        })
    }
    
    private func handleResponse(_ response: [String: Any]) {
        print("📥 Watch: Received response from iPhone: \(response)")
        
        if let success = response["success"] as? Bool, success {
            print("✅ Watch: Response marked as successful")
            // Clear any previous error when we get a successful response
            errorMessage = nil
            
            if let responseText = response["text"] as? String {
                print("📝 Watch: Response text: \(responseText)")
                let voiceResponse = VoiceResponse(
                    text: responseText,
                    success: true,
                    audioBase64: response["audioBase64"] as? String
                )
                lastResponse = voiceResponse
                updateStatus(.playing)
                
                // Play audio if available
                if let audioBase64 = response["audioBase64"] as? String, !audioBase64.isEmpty {
                    playAudioResponse(audioBase64)
                } else {
                    print("🔇 Watch: No audio data in response")
                }
                
                // Return to idle after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.updateStatus(.idle)
                }
            } else {
                print("❌ Watch: No text in response")
                errorMessage = "No response text"
                updateStatus(.error)
            }
        } else {
            let errorMsg = response["error"] as? String ?? "Unknown error from iPhone"
            print("❌ Watch: Error from iPhone: \(errorMsg)")
            errorMessage = errorMsg
            updateStatus(.error)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.updateStatus(.idle)
            }
        }
    }
    
    private func playAudioResponse(_ audioBase64: String) {
        guard let audioData = Data(base64Encoded: audioBase64) else {
            print("❌ Watch: Failed to decode base64 audio")
            return
        }
        
        print("🔊 Watch: Playing audio response (\(audioData.count) bytes)")
        
        do {
            // Set up audio session for playback
            print("🔊 Watch: Setting up audio session for playback...")
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Create and play audio
            print("🔊 Watch: Creating AVAudioPlayer...")
            let audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer.volume = 1.0
            
            // Add delegate to monitor playback
            print("🔊 Watch: Audio format: \(audioPlayer.format)")
            print("🔊 Watch: Number of channels: \(audioPlayer.numberOfChannels)")
            print("🔊 Watch: Current device volume: \(AVAudioSession.sharedInstance().outputVolume)")
            
            // Check audio route
            let currentRoute = AVAudioSession.sharedInstance().currentRoute
            for output in currentRoute.outputs {
                print("🔊 Watch: Audio output: \(output.portName) - \(output.portType.rawValue)")
            }
            
            // Check if audio player is ready
            if audioPlayer.prepareToPlay() {
                print("🔊 Watch: Audio player prepared successfully")
                let success = audioPlayer.play()
                print("🔊 Watch: Audio playback started: \(success ? "SUCCESS" : "FAILED")")
                print("🔊 Watch: Is playing: \(audioPlayer.isPlaying)")
                print("🔊 Watch: Audio duration: \(audioPlayer.duration) seconds")
                
                // Keep strong reference to audio player
                self.audioPlayer = audioPlayer
            } else {
                print("❌ Watch: Audio player failed to prepare")
            }
            
        } catch {
            print("❌ Watch: Failed to play audio: \(error)")
            print("❌ Watch: Audio error details: \(error.localizedDescription)")
        }
    }
    
    private func updateStatus(_ status: VoiceAssistantStatus) {
        currentStatus = status
        print("📊 Watch: Status updated to \(status.rawValue)")
    }
    
    private func processAudioDirectly(_ audioData: Data) {
        print("🔄 Watch: Processing audio directly...")
        updateStatus(.transcribing)
        
        // Use the WatchAPIClient for direct processing
        let watchAPIClient = WatchAPIClient.shared
        
        watchAPIClient.processVoiceCommand(audioData: audioData) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✅ Watch: Direct processing successful")
                    self?.handleDirectResponse(response)
                case .failure(let error):
                    print("❌ Watch: Direct processing failed: \(error.localizedDescription)")
                    self?.updateStatus(.error)
                    self?.errorMessage = "Direct processing failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func handleDirectResponse(_ response: VoiceResponse) {
        print("📥 Watch: Direct response received: \(response.text)")
        
        // If we have audio from the response, use it
        if let audioBase64 = response.audioBase64, !audioBase64.isEmpty {
            let voiceResponse = VoiceResponse(
                text: response.text,
                success: response.success,
                audioBase64: audioBase64
            )
            
            lastResponse = voiceResponse
            updateStatus(.playing)
            playAudioResponse(audioBase64)
        } else {
            // Generate audio using Google TTS
            generateAudioResponse(for: response.text) { [weak self] audioBase64 in
                DispatchQueue.main.async {
                    let voiceResponse = VoiceResponse(
                        text: response.text,
                        success: response.success,
                        audioBase64: audioBase64
                    )
                    
                    self?.lastResponse = voiceResponse
                    self?.updateStatus(.playing)
                    
                    if let audioBase64 = audioBase64 {
                        self?.playAudioResponse(audioBase64)
                    }
                }
            }
        }
        
        // Return to idle after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.updateStatus(.idle)
        }
    }
    
    private func generateAudioResponse(for text: String, completion: @escaping (String?) -> Void) {
        print("🔊 Watch: Generating audio for text: \(text)")
        
        // Use backend TTS service directly since GoogleTTSService was removed for security
        synthesizeTextViaBackend(text) { audioBase64 in
            DispatchQueue.main.async {
                if let audioBase64 = audioBase64 {
                    print("✅ Watch: Audio generated successfully")
                    completion(audioBase64)
                } else {
                    print("❌ Watch: Failed to generate audio")
                    completion(nil)
                }
            }
        }
    }
    
    private func synthesizeTextViaBackend(_ text: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://floe.cognetica.de/api/voice/synthesize") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("voice-assistant-api-key-2024", forHTTPHeaderField: "X-API-Key")
        
        let requestBody: [String: Any] = [
            "text": text,
            "voice": "en-US-Neural2-C",
            "languageCode": "en-US",
            "speakingRate": 1.1,
            "pitch": 0.0,
            "volumeGainDb": 2.0,
            "audioEncoding": "MP3"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Watch: Failed to serialize TTS request: \(error)")
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Watch: TTS request failed: \(error)")
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                print("❌ Watch: Invalid TTS response")
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let audioContent = json["audioBase64"] as? String {
                    completion(audioContent)
                } else {
                    print("❌ Watch: No audio content in TTS response")
                    completion(nil)
                }
            } catch {
                print("❌ Watch: Failed to parse TTS response: \(error)")
                completion(nil)
            }
        }.resume()
    }
}

// MARK: - WCSessionDelegate
extension PhoneConnector: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            print("📱 Watch: WCSession activation completed")
            print("📱 Watch: State: \(activationState.rawValue)")
            print("📱 Watch: isReachable: \(session.isReachable)")
            
            switch activationState {
            case .activated:
                print("✅ Watch: WCSession activated")
                self.isConnected = session.isReachable
            case .inactive:
                print("⚠️ Watch: WCSession inactive")
                self.isConnected = false
            case .notActivated:
                print("❌ Watch: WCSession not activated")
                self.isConnected = false
            @unknown default:
                self.isConnected = false
            }
            
            print("📱 Watch: Final isConnected: \(self.isConnected)")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("🔄 Watch: Reachability changed - iPhone reachable: \(session.isReachable)")
            self.isConnected = session.isReachable
            print("🔄 Watch: Final isConnected: \(self.isConnected)")
            
            // Post notification about connectivity change
            NotificationCenter.default.post(name: NSNotification.Name("watchConnectivityDidChange"), object: nil)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("📥 Watch: didReceiveMessage called with: \(message.keys)")
        DispatchQueue.main.async {
            if let type = message["type"] as? String {
                print("📥 Watch: Message type: \(type)")
                switch type {
                case "voiceResponse":
                    // Handle the voice response from iPhone
                    print("📥 Watch: Received voice response from iPhone")
                    self.handleResponse(message)
                case "statusUpdate":
                    if let statusRaw = message["status"] as? String,
                       let status = VoiceAssistantStatus(rawValue: statusRaw) {
                        self.updateStatus(status)
                    }
                case "error":
                    let errorMsg = message["message"] as? String ?? "Unknown error"
                    self.errorMessage = errorMsg
                    self.updateStatus(.error)
                default:
                    print("📥 Watch: Unknown message type: \(type)")
                    break
                }
            }
        }
    }
}
