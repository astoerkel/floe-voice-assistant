import Foundation
import AVFoundation
import Combine

class AudioLevelDetector: NSObject, ObservableObject {
    @Published var audioLevel: CGFloat = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private let updateInterval: TimeInterval = 0.03 // Update ~33 times per second for smoother animation
    
    override init() {
        super.init()
        setupAudioRecorder()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func setupAudioRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("audioLevelDetector.m4a")
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
        } catch {
            print("Failed to setup audio recorder: \(error)")
        }
    }
    
    func startMonitoring() {
        guard let recorder = audioRecorder else { return }
        
        recorder.record()
        
        levelTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    func stopMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioRecorder?.stop()
        audioLevel = 0.0
    }
    
    private func updateAudioLevel() {
        guard let recorder = audioRecorder else { return }
        
        recorder.updateMeters()
        
        // Get the average power for the first channel
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Convert from dB to linear scale (0.0 to 1.0)
        // Average power ranges from -160 dB (silence) to 0 dB (maximum)
        let minDb: Float = -60.0
        let maxDb: Float = -10.0
        
        let normalizedPower = (averagePower - minDb) / (maxDb - minDb)
        let clampedPower = max(0.0, min(1.0, normalizedPower))
        
        // Smooth the value to reduce jitter - more responsive
        let smoothingFactor: CGFloat = 0.6
        let newLevel = CGFloat(clampedPower)
        audioLevel = audioLevel * (1 - smoothingFactor) + newLevel * smoothingFactor
    }
}