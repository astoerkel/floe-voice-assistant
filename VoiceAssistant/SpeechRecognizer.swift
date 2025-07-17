//
//  SpeechRecognizer.swift
//  VoiceAssistant
//
//  Created by Amit Störkel on 16.07.25.
//
import Foundation
import Speech
import AVFoundation

class SpeechRecognizer: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    
    @Published var isAuthorized = false
    
    init() {
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.isAuthorized = status == .authorized
            }
        }
    }
    
    func transcribeAudio(_ audioData: Data) async throws -> String {
        guard isAuthorized else {
            throw SpeechError.notAuthorized
        }
        
        // Create a temporary file for the audio
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio.m4a")
        try audioData.write(to: tempURL)
        
        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: tempURL)
        request.shouldReportPartialResults = false
        
        // Perform recognition
        return try await withCheckedThrowingContinuation { continuation in
            speechRecognizer?.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}

enum SpeechError: Error {
    case notAuthorized
    case recognitionFailed
}
