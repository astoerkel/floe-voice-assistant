import AVFoundation
import Combine

/// Enhanced minimal audio recorder with proper error handling and status updates
class MinimalAudioRecorder: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var error: RecorderError?
    @Published var hasPermission = false
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private let recordingSession = AVAudioSession.sharedInstance()
    
    // MARK: - Error Types
    enum RecorderError: LocalizedError, Equatable {
        case permissionDenied
        case setupFailed(String)
        case recordingFailed(String)
        case noRecordingAvailable
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Microphone permission denied. Please enable in Settings."
            case .setupFailed(let reason):
                return "Failed to setup recorder: \(reason)"
            case .recordingFailed(let reason):
                return "Recording failed: \(reason)"
            case .noRecordingAvailable:
                return "No recording available"
            }
        }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        checkPermission()
    }
    
    // MARK: - Permission Handling
    func checkPermission() {
        switch recordingSession.recordPermission {
        case .granted:
            hasPermission = true
        case .denied:
            hasPermission = false
            error = .permissionDenied
        case .undetermined:
            recordingSession.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                    if !granted {
                        self?.error = .permissionDenied
                    }
                }
            }
        @unknown default:
            hasPermission = false
        }
    }
    
    // MARK: - Recording Methods
    func startRecording() {
        // Check permission first
        guard hasPermission else {
            error = .permissionDenied
            return
        }
        
        // Configure audio session
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try recordingSession.setActive(true)
            
            // Create recording URL with timestamp - using M4A for SFSpeechRecognizer compatibility
            let timestamp = Date().timeIntervalSince1970
            let fileName = "recording_\(timestamp).m4a"
            let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            // Configure recording settings for M4A format (compatible with SFSpeechRecognizer)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100, // 44.1kHz for high quality
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: 64000 // 64kbps for good quality/size balance
            ]
            
            // Create and prepare recorder
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            // Start recording
            if audioRecorder?.record() == true {
                isRecording = true
                recordingTime = 0
                error = nil
                
                // Start timers
                startTimers()
                
                print("📍 Recording started: \(audioURL.lastPathComponent)")
            } else {
                throw NSError(domain: "RecorderError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"])
            }
            
        } catch {
            self.error = .setupFailed(error.localizedDescription)
            print("❌ Recording setup failed: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() -> URL? {
        guard isRecording, let recorder = audioRecorder else {
            error = .noRecordingAvailable
            return nil
        }
        
        // Stop recording
        recorder.stop()
        isRecording = false
        
        // Stop timers
        stopTimers()
        
        // Deactivate audio session
        try? recordingSession.setActive(false)
        
        print("🛑 Recording stopped: \(recorder.url.lastPathComponent)")
        print("📏 Duration: \(recordingTime)s")
        
        // Verify file exists and size
        if FileManager.default.fileExists(atPath: recorder.url.path) {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: recorder.url.path),
               let fileSize = attributes[.size] as? Int64 {
                print("📁 File size: \(fileSize) bytes")
            }
        } else {
            print("❌ Recording file not found!")
        }
        
        return recorder.url
    }
    
    func pauseRecording() {
        guard isRecording, let recorder = audioRecorder else { return }
        recorder.pause()
        stopTimers()
    }
    
    func resumeRecording() {
        guard let recorder = audioRecorder else { return }
        recorder.record()
        startTimers()
    }
    
    func deleteRecording() {
        guard let url = audioRecorder?.url else { return }
        
        audioRecorder?.deleteRecording()
        audioRecorder = nil
        
        // Try to delete file as well
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Timer Management
    private func startTimers() {
        // Recording time timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingTime += 0.1
        }
        
        // Audio level timer
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0
    }
    
    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        let decibels = recorder.averagePower(forChannel: 0)
        
        // Convert decibels to 0-1 range
        let minDecibels: Float = -60
        let normalizedLevel = max(0, min(1, (decibels - minDecibels) / -minDecibels))
        
        DispatchQueue.main.async {
            self.audioLevel = normalizedLevel
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension MinimalAudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            error = .recordingFailed("Recording interrupted")
        }
        isRecording = false
        stopTimers()
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        self.error = .recordingFailed(error?.localizedDescription ?? "Unknown encoding error")
        isRecording = false
        stopTimers()
    }
}