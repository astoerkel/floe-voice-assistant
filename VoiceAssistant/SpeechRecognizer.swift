import Foundation
import Speech
import AVFoundation
import Combine

public class SpeechRecognizer: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    let enhancedSpeechRecognizer: EnhancedSpeechRecognizer
    
    @Published var isAuthorized = false
    @Published var isEnhanced = false
    @Published var useHybridMode = true
    @Published var processingMode: EnhancedSpeechRecognizer.ProcessingMode = .hybrid
    @Published var confidenceScore: Float = 0.0
    
    init() {
        self.enhancedSpeechRecognizer = EnhancedSpeechRecognizer()
        checkAuthorization()
        setupEnhanced()
    }
    
    private func setupEnhanced() {
        // Subscribe to enhanced recognizer updates
        enhancedSpeechRecognizer.$isEnhanced
            .receive(on: DispatchQueue.main)
            .assign(to: &$isEnhanced)
            
        enhancedSpeechRecognizer.$processingMode
            .receive(on: DispatchQueue.main)
            .assign(to: &$processingMode)
            
        enhancedSpeechRecognizer.$confidenceScore
            .receive(on: DispatchQueue.main)
            .assign(to: &$confidenceScore)
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
    
    // MARK: - Hybrid Transcription (Enhanced + Fallback)
    
    func transcribe(_ audioData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        print("🎤 SpeechRecognizer: Starting hybrid transcription of \(audioData.count) bytes")
        
        guard isAuthorized else {
            print("❌ SpeechRecognizer: Not authorized")
            completion(.failure(SpeechRecognitionError.notAuthorized))
            return
        }
        
        // Use enhanced transcription if available and enabled
        if useHybridMode && isEnhanced {
            enhancedTranscribe(audioData, completion: completion)
        } else {
            standardTranscribe(audioData, completion: completion)
        }
    }
    
    private func enhancedTranscribe(_ audioData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        print("🚀 SpeechRecognizer: Using enhanced transcription")
        
        enhancedSpeechRecognizer.enhancedTranscribe(audioData) { result in
            switch result {
            case .success(let enhancedResult):
                print("✅ Enhanced transcription complete - confidence: \(enhancedResult.confidence)")
                
                // Check if confidence is high enough
                if enhancedResult.confidence >= 0.75 {
                    completion(.success(enhancedResult.text))
                } else {
                    // Fall back to standard transcription for low confidence
                    print("⚠️ Low confidence (\(enhancedResult.confidence)), falling back to standard")
                    self.standardTranscribe(audioData) { fallbackResult in
                        switch fallbackResult {
                        case .success(let fallbackText):
                            // Choose the better result
                            let betterResult = enhancedResult.confidence > 0.5 ? enhancedResult.text : fallbackText
                            completion(.success(betterResult))
                        case .failure:
                            // Use enhanced result even if confidence is lower
                            completion(.success(enhancedResult.text))
                        }
                    }
                }
                
            case .failure(let error):
                print("❌ Enhanced transcription failed: \(error.localizedDescription)")
                // Fall back to standard transcription
                self.standardTranscribe(audioData, completion: completion)
            }
        }
    }
    
    private func standardTranscribe(_ audioData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        print("🎤 SpeechRecognizer: Using standard transcription")
        
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
    
    // MARK: - Enhanced Real-time Transcription
    
    func transcribeRealTime(_ audioData: Data, partialResultsHandler: @escaping (String) -> Void, completion: @escaping (Result<String, Error>) -> Void) {
        print("🎤 SpeechRecognizer: Starting enhanced real-time transcription of \(audioData.count) bytes")
        
        guard isAuthorized else {
            print("❌ SpeechRecognizer: Not authorized")
            completion(.failure(SpeechRecognitionError.notAuthorized))
            return
        }
        
        // Use enhanced real-time transcription if available
        if useHybridMode && isEnhanced {
            enhancedRealTimeTranscribe(audioData, partialResultsHandler: partialResultsHandler, completion: completion)
        } else {
            standardRealTimeTranscribe(audioData, partialResultsHandler: partialResultsHandler, completion: completion)
        }
    }
    
    private func enhancedRealTimeTranscribe(_ audioData: Data, partialResultsHandler: @escaping (String) -> Void, completion: @escaping (Result<String, Error>) -> Void) {
        print("🚀 SpeechRecognizer: Using enhanced real-time transcription")
        
        enhancedSpeechRecognizer.startEnhancedRealTimeTranscription(
            partialResultsHandler: { enhancedResult in
                // Update confidence score
                DispatchQueue.main.async {
                    self.confidenceScore = enhancedResult.confidence
                    self.processingMode = enhancedResult.processingMode
                }
                
                // Pass through enhanced text with confidence indicators
                let enhancedText = enhancedResult.confidence > 0.8 ? 
                    enhancedResult.text : 
                    enhancedResult.text + " ⚠️"
                
                partialResultsHandler(enhancedText)
            },
            completion: { result in
                switch result {
                case .success(let enhancedResult):
                    print("✅ Enhanced real-time transcription complete")
                    completion(.success(enhancedResult.text))
                case .failure(let error):
                    print("❌ Enhanced real-time transcription failed: \(error.localizedDescription)")
                    // Fall back to standard real-time transcription
                    self.standardRealTimeTranscribe(audioData, partialResultsHandler: partialResultsHandler, completion: completion)
                }
            }
        )
    }
    
    private func standardRealTimeTranscribe(_ audioData: Data, partialResultsHandler: @escaping (String) -> Void, completion: @escaping (Result<String, Error>) -> Void) {
        print("🎤 SpeechRecognizer: Using standard real-time transcription")
        
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
    
    // MARK: - Enhanced Features Control
    
    func toggleHybridMode() {
        useHybridMode.toggle()
        print("🔄 SpeechRecognizer: Hybrid mode \(useHybridMode ? "enabled" : "disabled")")
    }
    
    func setProcessingMode(_ mode: EnhancedSpeechRecognizer.ProcessingMode) {
        enhancedSpeechRecognizer.processingMode = mode
        print("🎯 SpeechRecognizer: Processing mode set to \(mode.rawValue)")
    }
    
    // MARK: - Learning and Adaptation
    
    func learnFromCorrection(original: String, corrected: String) {
        guard isEnhanced else { return }
        
        Task {
            await enhancedSpeechRecognizer.getVocabularyManager().learnFromTranscription(original, correctedText: corrected)
            print("📚 SpeechRecognizer: Learned from correction: '\(original)' -> '\(corrected)'")
        }
    }
    
    func addCustomVocabulary(terms: [String], domain: VocabularyManager.VocabularyDomain = .custom) {
        guard isEnhanced else { return }
        
        Task {
            for term in terms {
                await enhancedSpeechRecognizer.getVocabularyManager().addCustomTerm(term, domain: domain)
            }
            print("📝 SpeechRecognizer: Added \(terms.count) custom terms to \(domain.rawValue)")
        }
    }
    
    func getVocabularyStats() -> VocabularyStats? {
        guard isEnhanced else { return nil }
        return enhancedSpeechRecognizer.getVocabularyManager().getVocabularyStats()
    }
    
    func getEnhancementStatus() -> [String: Any] {
        var status: [String: Any] = [
            "isEnhanced": isEnhanced,
            "useHybridMode": useHybridMode,
            "processingMode": processingMode.rawValue,
            "confidenceScore": confidenceScore
        ]
        
        if isEnhanced {
            status["enhancements"] = enhancedSpeechRecognizer.enhancements
            status["vocabularyCount"] = enhancedSpeechRecognizer.getVocabularyManager().vocabularyCount
            
            if let patternLearning = enhancedSpeechRecognizer.getPatternLearning().exportLearningData() as? [String: Any] {
                status["patternLearning"] = patternLearning
            }
        }
        
        return status
    }
    
    // MARK: - Privacy Controls
    
    func resetLearningData() {
        guard isEnhanced else { return }
        
        Task {
            await enhancedSpeechRecognizer.getPatternLearning().resetLearning()
            print("🔄 SpeechRecognizer: Learning data reset")
        }
    }
    
    func exportPrivacyReport() -> [String: Any] {
        guard isEnhanced else { 
            return ["status": "Enhanced features not available"]
        }
        
        var report: [String: Any] = [
            "enhanced_features_enabled": true,
            "learning_enabled": enhancedSpeechRecognizer.getPatternLearning().isLearningEnabled,
            "vocabulary_learning": true,
            "pattern_learning": true,
            "data_encryption": "AES-256-GCM",
            "local_storage_only": true
        ]
        
        if let stats = getVocabularyStats() {
            report["vocabulary_stats"] = [
                "total_terms": stats.totalTerms,
                "custom_terms": stats.customTerms,
                "user_corrections": stats.userCorrections,
                "last_updated": stats.lastUpdated
            ]
        }
        
        return report
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
