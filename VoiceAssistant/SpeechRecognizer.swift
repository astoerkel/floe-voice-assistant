import Foundation
import Speech
import AVFoundation

class SpeechRecognizer: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    @Published var isAuthorized = false
    
    init() {
        checkAuthorization()
    }
    
    private func checkAuthorization() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            requestAuthorization()
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.isAuthorized = (status == .authorized)
            }
        }
    }
    
    func transcribe(_ audioData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        print("🎤 SpeechRecognizer: Starting transcription of \(audioData.count) bytes")
        
        guard isAuthorized else {
            print("❌ SpeechRecognizer: Not authorized")
            completion(.failure(SpeechRecognitionError.notAuthorized))
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ SpeechRecognizer: Not available")
            completion(.failure(SpeechRecognitionError.notAvailable))
            return
        }
        
        do {
            // Create temporary file with the appropriate extension
            let tempURL: URL
            
            // Check if this is a WAV file
            if audioData.count > 4 {
                let header = audioData.subdata(in: 0..<4)
                if let headerString = String(data: header, encoding: .ascii), headerString == "RIFF" {
                    print("🎤 SpeechRecognizer: Detected WAV format")
                    tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio.wav")
                } else {
                    print("🎤 SpeechRecognizer: Using M4A format")
                    tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio.m4a")
                }
            } else {
                tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio.m4a")
            }
            
            try audioData.write(to: tempURL)
            print("🎤 SpeechRecognizer: Created temp file at \(tempURL)")
            
            // Create recognition request
            let request = SFSpeechURLRecognitionRequest(url: tempURL)
            request.shouldReportPartialResults = false
            
            // Perform recognition
            speechRecognizer.recognitionTask(with: request) { result, error in
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)
                
                if let error = error {
                    print("❌ SpeechRecognizer: Recognition error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let result = result else {
                    print("❌ SpeechRecognizer: No result")
                    completion(.failure(SpeechRecognitionError.noResult))
                    return
                }
                
                let transcription = result.bestTranscription.formattedString
                print("✅ SpeechRecognizer: Transcription: \(transcription)")
                completion(.success(transcription))
            }
            
        } catch {
            print("❌ SpeechRecognizer: File error: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    // Real-time transcription for live audio (for future enhancement)
    func transcribeRealTime(_ audioData: Data, partialResultsHandler: @escaping (String) -> Void, completion: @escaping (Result<String, Error>) -> Void) {
        print("🎤 SpeechRecognizer: Starting real-time transcription of \(audioData.count) bytes")
        
        guard isAuthorized else {
            print("❌ SpeechRecognizer: Not authorized")
            completion(.failure(SpeechRecognitionError.notAuthorized))
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ SpeechRecognizer: Not available")
            completion(.failure(SpeechRecognitionError.notAvailable))
            return
        }
        
        do {
            // Create temporary file with the appropriate extension
            let tempURL: URL
            
            // Check if this is a WAV file
            if audioData.count > 4 {
                let header = audioData.subdata(in: 0..<4)
                if let headerString = String(data: header, encoding: .ascii), headerString == "RIFF" {
                    print("🎤 SpeechRecognizer: Detected WAV format")
                    tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio_realtime.wav")
                } else {
                    print("🎤 SpeechRecognizer: Using M4A format")
                    tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio_realtime.m4a")
                }
            } else {
                tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio_realtime.m4a")
            }
            
            try audioData.write(to: tempURL)
            print("🎤 SpeechRecognizer: Created temp file at \(tempURL)")
            
            // Create recognition request with partial results
            let request = SFSpeechURLRecognitionRequest(url: tempURL)
            request.shouldReportPartialResults = true
            
            // Perform recognition
            speechRecognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)
                    print("❌ SpeechRecognizer: Recognition error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let result = result else {
                    try? FileManager.default.removeItem(at: tempURL)
                    print("❌ SpeechRecognizer: No result")
                    completion(.failure(SpeechRecognitionError.noResult))
                    return
                }
                
                let transcription = result.bestTranscription.formattedString
                print("📝 SpeechRecognizer: Partial transcription: \(transcription)")
                
                // Send partial results
                DispatchQueue.main.async {
                    partialResultsHandler(transcription)
                }
                
                // Send final result when complete
                if result.isFinal {
                    try? FileManager.default.removeItem(at: tempURL)
                    print("✅ SpeechRecognizer: Final transcription: \(transcription)")
                    completion(.success(transcription))
                }
            }
            
        } catch {
            print("❌ SpeechRecognizer: File error: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
}

enum SpeechRecognitionError: LocalizedError {
    case notAuthorized
    case notAvailable
    case noResult
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized"
        case .notAvailable:
            return "Speech recognition not available"
        case .noResult:
            return "No transcription result"
        }
    }
}
