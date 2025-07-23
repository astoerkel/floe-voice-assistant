import Foundation
import Speech
import AVFoundation
import CoreML
import Contacts
import EventKit

// MARK: - Enhanced Speech Recognizer
class EnhancedSpeechRecognizer: ObservableObject {
    private let baseSpeechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let speechEnhancementModel: SpeechEnhancementModel
    private let vocabularyManager: VocabularyManager
    private let patternLearning: SpeechPatternLearning
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var isAuthorized = false
    @Published var isEnhanced = false
    @Published var confidenceScore: Float = 0.0
    @Published var processingMode: ProcessingMode = .onDevice
    @Published var enhancements: [String] = []
    
    enum ProcessingMode: String, CaseIterable {
        case onDevice = "On-Device"
        case hybrid = "Hybrid"
        case server = "Server"
        case enhanced = "Enhanced"
    }
    
    enum EnhancementType: String, CaseIterable {
        case noiseReduction = "Noise Reduction"
        case vocabularyBoost = "Vocabulary Boost"
        case accentAdaptation = "Accent Adaptation"
        case patternLearning = "Pattern Learning"
        case contextAware = "Context Aware"
    }
    
    private let confidenceThreshold: Float = 0.85
    private let enhancementThreshold: Float = 0.75
    
    init() {
        self.speechEnhancementModel = SpeechEnhancementModel()
        self.vocabularyManager = VocabularyManager()
        self.patternLearning = SpeechPatternLearning()
        
        checkAuthorization()
        setupAudioEngine()
    }
    
    private func checkAuthorization() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            isAuthorized = true
            initializeEnhancements()
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
                if self.isAuthorized {
                    self.initializeEnhancements()
                }
            }
        }
    }
    
    private func initializeEnhancements() {
        Task {
            await vocabularyManager.loadUserVocabulary()
            await patternLearning.loadUserPatterns()
            
            DispatchQueue.main.async {
                self.isEnhanced = true
                self.updateEnhancements()
            }
        }
    }
    
    private func setupAudioEngine() {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
    }
    
    // MARK: - Enhanced Transcription
    
    func enhancedTranscribe(_ audioData: Data, completion: @escaping (Result<EnhancedTranscriptionResult, Error>) -> Void) {
        print("🚀 EnhancedSpeechRecognizer: Starting enhanced transcription of \(audioData.count) bytes")
        
        guard isAuthorized else {
            completion(.failure(SpeechRecognitionError.notAuthorized))
            return
        }
        
        Task {
            do {
                // Step 1: Preprocess audio with Core ML
                let enhancedAudioData = await speechEnhancementModel.preprocessAudio(audioData)
                
                // Step 2: Apply noise reduction
                let denoisedData = await applyNoiseReduction(enhancedAudioData)
                
                // Step 3: Get multiple transcription candidates
                let candidates = await getTranscriptionCandidates(denoisedData)
                
                // Step 4: Apply vocabulary boosting
                let boostedCandidates = await vocabularyManager.applyVocabularyBoosting(candidates)
                
                // Step 5: Apply pattern learning
                let patternEnhanced = await patternLearning.enhanceWithPatterns(boostedCandidates)
                
                // Step 6: Select best result with confidence scoring
                let result = await selectBestTranscription(patternEnhanced)
                
                // Step 7: Learn from result for future improvements
                await patternLearning.learnFromResult(result)
                
                DispatchQueue.main.async {
                    self.confidenceScore = result.confidence
                    self.processingMode = result.processingMode
                    self.updateEnhancements()
                    completion(.success(result))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Real-time Enhanced Transcription
    
    func startEnhancedRealTimeTranscription(
        partialResultsHandler: @escaping (EnhancedTranscriptionResult) -> Void,
        completion: @escaping (Result<EnhancedTranscriptionResult, Error>) -> Void
    ) {
        print("🎙️ EnhancedSpeechRecognizer: Starting real-time enhanced transcription")
        
        guard isAuthorized else {
            completion(.failure(SpeechRecognitionError.notAuthorized))
            return
        }
        
        guard let speechRecognizer = baseSpeechRecognizer, speechRecognizer.isAvailable else {
            completion(.failure(SpeechRecognitionError.notAvailable))
            return
        }
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionRequest = nil
        
        // Create enhanced recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            completion(.failure(SpeechRecognitionError.noResult))
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = processingMode == .onDevice
        
        // Apply custom vocabulary
        if isEnhanced {
            recognitionRequest.contextualStrings = vocabularyManager.getContextualStrings()
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Enhanced recognition error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let result = result else {
                completion(.failure(SpeechRecognitionError.noResult))
                return
            }
            
            Task {
                let enhancedResult = await self.enhanceRecognitionResult(result)
                
                DispatchQueue.main.async {
                    if result.isFinal {
                        completion(.success(enhancedResult))
                    } else {
                        partialResultsHandler(enhancedResult)
                    }
                }
            }
        }
        
        // Start audio engine
        do {
            try audioEngine.start()
        } catch {
            completion(.failure(error))
        }
    }
    
    func stopRealTimeTranscription() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    // MARK: - Core ML Enhancement Methods
    
    private func applyNoiseReduction(_ audioData: Data) async -> Data {
        guard isEnhanced else { return audioData }
        
        do {
            return try await speechEnhancementModel.reduceNoise(audioData)
        } catch {
            print("⚠️ Noise reduction failed: \(error.localizedDescription)")
            return audioData
        }
    }
    
    private func getTranscriptionCandidates(_ audioData: Data) async -> [TranscriptionCandidate] {
        return await withTaskGroup(of: TranscriptionCandidate?.self) { group in
            var candidates: [TranscriptionCandidate] = []
            
            // Primary: Enhanced on-device recognition
            group.addTask {
                await self.performOnDeviceRecognition(audioData)
            }
            
            // Secondary: Standard recognition
            group.addTask {
                await self.performStandardRecognition(audioData)
            }
            
            // Tertiary: Context-aware recognition
            if self.isEnhanced {
                group.addTask {
                    await self.performContextAwareRecognition(audioData)
                }
            }
            
            for await candidate in group {
                if let candidate = candidate {
                    candidates.append(candidate)
                }
            }
            
            return candidates
        }
    }
    
    private func performOnDeviceRecognition(_ audioData: Data) async -> TranscriptionCandidate? {
        return await withCheckedContinuation { continuation in
            do {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("enhanced_audio.m4a")
                try audioData.write(to: tempURL)
                
                let request = SFSpeechURLRecognitionRequest(url: tempURL)
                request.shouldReportPartialResults = false
                request.requiresOnDeviceRecognition = true
                
                baseSpeechRecognizer?.recognitionTask(with: request) { result, error in
                    try? FileManager.default.removeItem(at: tempURL)
                    
                    if let error = error {
                        print("❌ On-device recognition error: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    guard let result = result else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let candidate = TranscriptionCandidate(
                        text: result.bestTranscription.formattedString,
                        confidence: Float(result.bestTranscription.averageConfidence),
                        source: .onDevice,
                        segments: result.bestTranscription.segments.map { segment in
                            TranscriptionSegment(
                                text: segment.substring,
                                confidence: Float(segment.confidence),
                                timestamp: segment.timestamp,
                                duration: segment.duration
                            )
                        }
                    )
                    
                    continuation.resume(returning: candidate)
                }
            } catch {
                print("❌ On-device recognition setup error: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func performStandardRecognition(_ audioData: Data) async -> TranscriptionCandidate? {
        return await withCheckedContinuation { continuation in
            do {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("standard_audio.m4a")
                try audioData.write(to: tempURL)
                
                let request = SFSpeechURLRecognitionRequest(url: tempURL)
                request.shouldReportPartialResults = false
                request.requiresOnDeviceRecognition = false
                
                baseSpeechRecognizer?.recognitionTask(with: request) { result, error in
                    try? FileManager.default.removeItem(at: tempURL)
                    
                    if let error = error {
                        print("❌ Standard recognition error: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    guard let result = result else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let candidate = TranscriptionCandidate(
                        text: result.bestTranscription.formattedString,
                        confidence: Float(result.bestTranscription.averageConfidence),
                        source: .server,
                        segments: result.bestTranscription.segments.map { segment in
                            TranscriptionSegment(
                                text: segment.substring,
                                confidence: Float(segment.confidence),
                                timestamp: segment.timestamp,
                                duration: segment.duration
                            )
                        }
                    )
                    
                    continuation.resume(returning: candidate)
                }
            } catch {
                print("❌ Standard recognition setup error: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func performContextAwareRecognition(_ audioData: Data) async -> TranscriptionCandidate? {
        let contextStrings = await vocabularyManager.getContextualStrings()
        
        return await withCheckedContinuation { continuation in
            do {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("context_audio.m4a")
                try audioData.write(to: tempURL)
                
                let request = SFSpeechURLRecognitionRequest(url: tempURL)
                request.shouldReportPartialResults = false
                request.contextualStrings = contextStrings
                
                baseSpeechRecognizer?.recognitionTask(with: request) { result, error in
                    try? FileManager.default.removeItem(at: tempURL)
                    
                    if let error = error {
                        print("❌ Context-aware recognition error: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    guard let result = result else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let candidate = TranscriptionCandidate(
                        text: result.bestTranscription.formattedString,
                        confidence: Float(result.bestTranscription.averageConfidence),
                        source: .contextAware,
                        segments: result.bestTranscription.segments.map { segment in
                            TranscriptionSegment(
                                text: segment.substring,
                                confidence: Float(segment.confidence),
                                timestamp: segment.timestamp,
                                duration: segment.duration
                            )
                        }
                    )
                    
                    continuation.resume(returning: candidate)
                }
            } catch {
                print("❌ Context-aware recognition setup error: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func selectBestTranscription(_ candidates: [TranscriptionCandidate]) async -> EnhancedTranscriptionResult {
        guard !candidates.isEmpty else {
            return EnhancedTranscriptionResult(
                text: "",
                confidence: 0.0,
                processingMode: .onDevice,
                enhancements: [],
                candidates: [],
                processingTime: 0.0,
                source: .onDevice
            )
        }
        
        // Sort by confidence
        let sortedCandidates = candidates.sorted { $0.confidence > $1.confidence }
        let bestCandidate = sortedCandidates.first!
        
        // Determine processing mode
        let mode: ProcessingMode
        if bestCandidate.confidence >= confidenceThreshold {
            mode = bestCandidate.source == .onDevice ? .onDevice : .enhanced
        } else {
            mode = .hybrid
        }
        
        // Collect applied enhancements
        var appliedEnhancements: [String] = []
        if bestCandidate.confidence > enhancementThreshold {
            appliedEnhancements.append(EnhancementType.vocabularyBoost.rawValue)
        }
        if bestCandidate.source == .contextAware {
            appliedEnhancements.append(EnhancementType.contextAware.rawValue)
        }
        appliedEnhancements.append(EnhancementType.patternLearning.rawValue)
        
        return EnhancedTranscriptionResult(
            text: bestCandidate.text,
            confidence: bestCandidate.confidence,
            processingMode: mode,
            enhancements: appliedEnhancements,
            candidates: sortedCandidates,
            processingTime: 0.0, // TODO: Implement actual timing
            source: bestCandidate.source
        )
    }
    
    private func enhanceRecognitionResult(_ result: SFSpeechRecognitionResult) async -> EnhancedTranscriptionResult {
        let baseCandidate = TranscriptionCandidate(
            text: result.bestTranscription.formattedString,
            confidence: Float(result.bestTranscription.averageConfidence),
            source: .onDevice,
            segments: result.bestTranscription.segments.map { segment in
                TranscriptionSegment(
                    text: segment.substring,
                    confidence: Float(segment.confidence),
                    timestamp: segment.timestamp,
                    duration: segment.duration
                )
            }
        )
        
        let enhancedCandidates = await vocabularyManager.applyVocabularyBoosting([baseCandidate])
        let patternEnhanced = await patternLearning.enhanceWithPatterns(enhancedCandidates)
        
        return await selectBestTranscription(patternEnhanced)
    }
    
    private func updateEnhancements() {
        var activeEnhancements: [String] = []
        
        if isEnhanced {
            activeEnhancements.append(EnhancementType.noiseReduction.rawValue)
            activeEnhancements.append(EnhancementType.vocabularyBoost.rawValue)
            activeEnhancements.append(EnhancementType.accentAdaptation.rawValue)
            activeEnhancements.append(EnhancementType.patternLearning.rawValue)
            activeEnhancements.append(EnhancementType.contextAware.rawValue)
        }
        
        enhancements = activeEnhancements
    }
}

// MARK: - Supporting Data Structures

struct EnhancedTranscriptionResult {
    let text: String
    let confidence: Float
    let processingMode: EnhancedSpeechRecognizer.ProcessingMode
    let enhancements: [String]
    let candidates: [TranscriptionCandidate]
    let processingTime: TimeInterval
    let source: TranscriptionSource
}

struct TranscriptionCandidate {
    let text: String
    let confidence: Float
    let source: TranscriptionSource
    let segments: [TranscriptionSegment]
}

struct TranscriptionSegment {
    let text: String
    let confidence: Float
    let timestamp: TimeInterval
    let duration: TimeInterval
}

enum TranscriptionSource: String, CaseIterable {
    case onDevice = "On-Device"
    case server = "Server"
    case contextAware = "Context-Aware"
    case enhanced = "Enhanced"
}

extension SpeechRecognitionError {
    static let enhancementFailed = SpeechRecognitionError.noResult
    static let modelNotAvailable = SpeechRecognitionError.notAvailable
}