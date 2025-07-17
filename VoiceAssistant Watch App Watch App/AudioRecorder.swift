//
//  AudioRecorder.swift
//  VoiceAssistant
//
//  Created by Amit Störkel on 16.07.25.
//
import Foundation
import AVFoundation
import WatchKit

class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession
    
    @Published var isRecording: Bool = false
    @Published var audioLevels: [Float] = []
    
    override init() {
        self.audioSession = AVAudioSession.sharedInstance()
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent("recording.m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            startLevelMonitoring()
            
            // Haptic feedback
            WKInterfaceDevice.current().play(.start)
            
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() -> Data? {
        guard isRecording else { return nil }
        
        audioRecorder?.stop()
        isRecording = false
        audioLevels = []
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.stop)
        
        // Return audio data
        if let url = audioRecorder?.url {
            return try? Data(contentsOf: url)
        }
        
        return nil
    }
    
    private func startLevelMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard self.isRecording else {
                timer.invalidate()
                return
            }
            
            self.audioRecorder?.updateMeters()
            let level = self.audioRecorder?.averagePower(forChannel: 0) ?? -80
            
            // Convert to 0-1 range for visualization
            let normalizedLevel = max(0, (level + 80) / 80)
            
            DispatchQueue.main.async {
                self.audioLevels.append(normalizedLevel)
                
                // Keep only last 20 levels for visualization
                if self.audioLevels.count > 20 {
                    self.audioLevels.removeFirst()
                }
            }
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        }
    }
}
