import Foundation
import Speech
import AVFoundation

public class SimpleSpeechRecognizer: ObservableObject {
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
        guard isAuthorized else {
            completion(.failure(VoiceAssistantError.transcriptionFailed))
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            completion(.failure(VoiceAssistantError.transcriptionFailed))
            return
        }
        
        // Write audio data to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("speech_\(UUID().uuidString).wav")
        
        do {
            try audioData.write(to: tempURL)
            
            let request = SFSpeechURLRecognitionRequest(url: tempURL)
            request.shouldReportPartialResults = false
            
            speechRecognizer.recognitionTask(with: request) { result, error in
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let result = result else {
                    completion(.failure(VoiceAssistantError.transcriptionFailed))
                    return
                }
                
                if result.isFinal {
                    let transcription = result.bestTranscription.formattedString
                    completion(.success(transcription))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}