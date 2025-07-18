import Foundation
import SwiftUI
import AVFoundation
import Combine

class WatchVoiceManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var currentState: VoiceState = .idle
    @Published var audioLevels: [Float] = []
    @Published var responseReceived: String = ""
    @Published var isRecording: Bool = false
    
    private let hapticManager = HapticFeedbackManager.shared
    private let phoneConnector = PhoneConnector.shared
    private var audioRecorder: AVAudioRecorder?
    private var audioSession = AVAudioSession.sharedInstance()
    private var levelTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var recordingStartTime: Date?
    private let minimumRecordingDuration: TimeInterval = 0.5 // 500ms minimum
    
    override init() {
        super.init()
        setupAudioSession()
        observePhoneConnectorChanges()
    }
    
    deinit {
        levelTimer?.invalidate()
    }
    
    private func setupAudioSession() {
        do {
            // Deactivate first to ensure clean state
            try audioSession.setActive(false)
            
            // Configure for watchOS with appropriate settings
            // Use playAndRecord for general use, but will switch to record when recording
            try audioSession.setCategory(.playAndRecord, 
                                       mode: .default, 
                                       options: [.allowBluetooth])
            
            // Activate the session
            try audioSession.setActive(true)
            print("✅ WatchVoiceManager: Audio session setup successful")
            
            // Log current audio session info
            let currentRoute = audioSession.currentRoute
            print("🔊 WatchVoiceManager: Audio route info:")
            for input in currentRoute.inputs {
                print("  Input: \(input.portName) - \(input.portType.rawValue)")
            }
            for output in currentRoute.outputs {
                print("  Output: \(output.portName) - \(output.portType.rawValue)")
            }
            
            // Log audio session configuration
            print("🔊 WatchVoiceManager: Sample rate: \(audioSession.sampleRate)")
            print("🔊 WatchVoiceManager: IO buffer duration: \(audioSession.ioBufferDuration)")
        } catch {
            print("❌ WatchVoiceManager: Failed to setup audio session: \(error)")
        }
    }
    
    private func observePhoneConnectorChanges() {
        phoneConnector.$currentStatus
            .sink { [weak self] status in
                self?.updateStateFromPhoneConnector(status)
            }
            .store(in: &cancellables)
        
        phoneConnector.$lastResponse
            .compactMap { $0 }
            .sink { [weak self] response in
                self?.handleResponse(response)
            }
            .store(in: &cancellables)
    }
    
    private func updateStateFromPhoneConnector(_ status: VoiceAssistantStatus) {
        switch status {
        case .idle:
            currentState = .idle
        case .recording:
            currentState = .listening
        case .transcribing, .processing:
            currentState = .processing
        case .playing:
            currentState = .responding
        case .error:
            currentState = .error
        }
    }
    
    private func handleResponse(_ response: VoiceResponse) {
        let actionType = hapticManager.determineActionType(from: response.text)
        hapticManager.triggerHaptic(for: .response(actionType))
        responseReceived = response.text
    }
    
    func startRecording() {
        // Check if we can process somehow (either via iPhone or directly)
        let canProcessViaPhone = phoneConnector.isConnected
        let canProcessDirectly = WatchAPIClient.shared.isConnected
        
        print("🔍 WatchVoiceManager: Can process via iPhone: \(canProcessViaPhone)")
        print("🔍 WatchVoiceManager: Can process directly: \(canProcessDirectly)")
        
        guard canProcessViaPhone || canProcessDirectly else {
            print("❌ WatchVoiceManager: No available processing method")
            currentState = .error
            hapticManager.triggerHaptic(for: .error)
            return
        }
        
        // Check microphone permissions
        checkMicrophonePermissions { [weak self] hasPermission in
            guard let self = self else { return }
            
            if !hasPermission {
                print("❌ WatchVoiceManager: Microphone permission denied")
                self.currentState = .error
                self.hapticManager.triggerHaptic(for: .error)
                return
            }
            
            self.performRecording()
        }
    }
    
    private func checkMicrophonePermissions(completion: @escaping (Bool) -> Void) {
        let microphoneStatus = AVAudioApplication.shared.recordPermission
        
        switch microphoneStatus {
        case .granted:
            print("✅ WatchVoiceManager: Microphone permission granted")
            completion(true)
        case .denied:
            print("❌ WatchVoiceManager: Microphone permission denied")
            completion(false)
        case .undetermined:
            print("⚠️ WatchVoiceManager: Microphone permission undetermined, requesting...")
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    print(granted ? "✅ WatchVoiceManager: Microphone permission granted" : "❌ WatchVoiceManager: Microphone permission denied")
                    completion(granted)
                }
            }
        @unknown default:
            print("❌ WatchVoiceManager: Unknown microphone permission status")
            completion(false)
        }
    }
    
    private func performRecording() {
        isRecording = true
        currentState = .listening
        recordingStartTime = Date()
        hapticManager.triggerHaptic(for: .listening)
        
        do {
            // Re-setup audio session before recording with watchOS-specific configuration
            try audioSession.setActive(false)
            
            // Use record category for better compatibility on watchOS
            try audioSession.setCategory(.record, 
                                       mode: .measurement,  // Better for voice recording
                                       options: [.allowBluetooth])
            
            try audioSession.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("watch_recording.wav")
            
            // Delete existing file if it exists
            if FileManager.default.fileExists(atPath: audioFilename.path) {
                try FileManager.default.removeItem(at: audioFilename)
                print("🗑️ WatchVoiceManager: Deleted existing recording file")
            }
            
            // Try different audio formats if AAC fails
            var settings: [String: Any] = [:]
            var audioRecorder: AVAudioRecorder?
            
            // Start with PCM format as it's more reliable on watchOS
            settings = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 8000,  // Lower sample rate for watchOS
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            
            do {
                audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                print("✅ WatchVoiceManager: Created PCM recorder")
            } catch {
                print("⚠️ WatchVoiceManager: PCM format failed, trying simplest format: \(error)")
                
                // Fallback: Simplest possible PCM format
                settings = [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM),
                    AVSampleRateKey: 8000,
                    AVNumberOfChannelsKey: 1
                ]
                
                audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                print("✅ WatchVoiceManager: Created simple PCM recorder")
            }
            
            guard let recorder = audioRecorder else {
                throw NSError(domain: "WatchVoiceManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio recorder"])
            }
            
            // Configure recorder
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            
            // Log audio session details for debugging
            print("🔍 WatchVoiceManager: Audio session category: \(audioSession.category.rawValue)")
            print("🔍 WatchVoiceManager: Audio session mode: \(audioSession.mode.rawValue)")
            print("🔍 WatchVoiceManager: Audio session sample rate: \(audioSession.sampleRate)")
            print("🔍 WatchVoiceManager: Recorder URL: \(recorder.url.path)")
            print("🔍 WatchVoiceManager: Recorder settings: \(recorder.settings)")
            
            // On watchOS, prepareToRecord often fails but recording still works
            // Try to prepare but don't fail if it doesn't work
            let prepareResult = recorder.prepareToRecord()
            print("🔍 WatchVoiceManager: prepareToRecord result: \(prepareResult)")
            
            if !prepareResult {
                print("⚠️ WatchVoiceManager: prepareToRecord failed, but will try recording anyway (common on watchOS)")
            }
            
            // Start recording
            let recordingStarted = recorder.record()
            
            if recordingStarted {
                self.audioRecorder = recorder
                startAudioLevelMonitoring()
                print("✅ WatchVoiceManager: Recording started successfully with PCM format")
            } else {
                print("❌ WatchVoiceManager: Failed to start recording - record() returned false")
                print("❌ WatchVoiceManager: Recorder URL: \(recorder.url)")
                print("❌ WatchVoiceManager: Recorder is recording: \(recorder.isRecording)")
                
                // If this was AAC format, the PCM fallback should have handled it
                // If we're here with PCM, something else is wrong
                isRecording = false
                currentState = .error
                hapticManager.triggerHaptic(for: .error)
            }
        } catch {
            print("❌ WatchVoiceManager: Failed to start recording: \(error)")
            isRecording = false
            currentState = .error
            hapticManager.triggerHaptic(for: .error)
        }
    }
    
    func stopRecording() {
        isRecording = false
        currentState = .processing
        hapticManager.triggerHaptic(for: .processing)
        
        levelTimer?.invalidate()
        
        // Check if we've recorded for the minimum duration
        if let startTime = recordingStartTime {
            let recordingDuration = Date().timeIntervalSince(startTime)
            if recordingDuration < minimumRecordingDuration {
                print("⚠️ WatchVoiceManager: Recording too short (\(recordingDuration)s), enforcing minimum duration")
                
                // Wait for the remaining time
                let remainingTime = minimumRecordingDuration - recordingDuration
                DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                    self.finishRecording()
                }
                return
            }
        }
        
        finishRecording()
    }
    
    private func finishRecording() {
        audioRecorder?.stop()
        
        guard let audioRecorder = audioRecorder else {
            print("❌ WatchVoiceManager: No audio recorder available")
            currentState = .error
            hapticManager.triggerHaptic(for: .error)
            return
        }
        
        // Add a small delay to ensure the recording is fully stopped
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.processRecordedAudio(from: audioRecorder.url)
        }
    }
    
    private func processRecordedAudio(from url: URL) {
        do {
            // Check if file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ WatchVoiceManager: Audio file does not exist at path: \(url.path)")
                currentState = .error
                hapticManager.triggerHaptic(for: .error)
                return
            }
            
            let audioData = try Data(contentsOf: url)
            print("✅ WatchVoiceManager: Recording stopped, got \(audioData.count) bytes")
            
            // Get file attributes for debugging
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                print("📁 WatchVoiceManager: File size on disk: \(fileSize) bytes")
            }
            
            // Check if audio data is too small (likely recording issue)
            if audioData.count < 1000 {
                print("❌ WatchVoiceManager: Audio data too small (\(audioData.count) bytes), recording may have failed")
                
                // Try to get more detailed error information
                if let recorder = audioRecorder {
                    print("🔍 WatchVoiceManager: Audio recorder was recording: \(recorder.isRecording)")
                    print("🔍 WatchVoiceManager: Audio recorder current time: \(recorder.currentTime)")
                    print("🔍 WatchVoiceManager: Audio recorder URL: \(recorder.url)")
                }
                
                currentState = .error
                hapticManager.triggerHaptic(for: .error)
                return
            }
            
            // The PhoneConnector will now handle both iPhone and direct processing
            phoneConnector.sendAudioData(audioData)
        } catch {
            print("❌ WatchVoiceManager: Failed to read audio file: \(error)")
            print("❌ WatchVoiceManager: Audio file path: \(url.path)")
            currentState = .error
            hapticManager.triggerHaptic(for: .error)
        }
    }
    
    private func startAudioLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAudioLevels()
        }
    }
    
    private func updateAudioLevels() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            audioLevels = []
            return
        }
        
        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        let normalizedLevel = max(0, (level + 80) / 80)
        
        audioLevels.append(normalizedLevel)
        if audioLevels.count > 50 {
            audioLevels.removeFirst()
        }
    }
    
    func handleVoiceInput() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func reset() {
        isRecording = false
        currentState = .idle
        audioLevels = []
        responseReceived = ""
        recordingStartTime = nil
        levelTimer?.invalidate()
        audioRecorder?.stop()
        audioRecorder = nil
    }
    
    // MARK: - AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("🎙️ WatchVoiceManager: Recording finished successfully: \(flag)")
        
        if !flag {
            print("❌ WatchVoiceManager: Recording failed during recording")
            DispatchQueue.main.async {
                self.currentState = .error
                self.hapticManager.triggerHaptic(for: .error)
            }
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ WatchVoiceManager: Recording encode error: \(error?.localizedDescription ?? "Unknown error")")
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.currentState = .error
            self.hapticManager.triggerHaptic(for: .error)
        }
    }
}