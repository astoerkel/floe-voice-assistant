import Foundation

/// Protocol for Text-to-Speech services
protocol TTSServiceProtocol {
    
    /// Synthesizes text to audio
    /// - Parameters:
    ///   - text: The text to synthesize
    ///   - settings: Voice and audio settings
    ///   - completion: Completion handler with audio data or error
    func synthesizeText(
        _ text: String,
        settings: TTSVoiceSettings,
        completion: @escaping (Result<Data, Error>) -> Void
    )
    
    /// Gets available voices for the service
    var availableVoices: [TTSVoice] { get }
    
    /// Service capabilities
    var supportsSSML: Bool { get }
    var maxTextLength: Int { get }
}

// MARK: - TTS Data Structures

/// Voice settings for TTS synthesis
struct TTSVoiceSettings {
    var voiceName: String
    var languageCode: String
    var speakingRate: Double  // 0.25 to 4.0
    var pitch: Double         // -20.0 to 20.0
    var volumeGainDb: Double  // -96.0 to 16.0
    var audioEncoding: TTSAudioEncoding
    
    static let `default` = TTSVoiceSettings(
        voiceName: "en-GB-Chirp3-HD-Sulafat",
        languageCode: "en-GB",
        speakingRate: 1.0,
        pitch: 0.0,
        volumeGainDb: 0.0,
        audioEncoding: .mp3
    )
    
    /// Platform-specific defaults
    static var platformDefault: TTSVoiceSettings {
        var settings = TTSVoiceSettings.default
        
        #if os(watchOS)
        // Watch-specific optimizations
        settings.voiceName = "en-US-Neural2-C"
        settings.speakingRate = 1.1  // Slightly faster for watch
        settings.volumeGainDb = 2.0  // Louder for small speakers
        #elseif os(iOS)
        // iPhone-specific optimizations
        settings.voiceName = "en-US-Neural2-F"
        settings.speakingRate = 1.0
        settings.volumeGainDb = 0.0
        #endif
        
        return settings
    }
}

/// Available TTS voice information
struct TTSVoice {
    let name: String
    let displayName: String
    let languageCode: String
    let gender: TTSVoiceGender
    let quality: TTSVoiceQuality
    
    static let sulafat = TTSVoice(
        name: "en-GB-Chirp3-HD-Sulafat",
        displayName: "Sulafat (British, Neural)",
        languageCode: "en-GB",
        gender: .neutral,
        quality: .premium
    )
    
    static let femaleUS = TTSVoice(
        name: "en-US-Neural2-F",
        displayName: "Female Voice (US, Neural)",
        languageCode: "en-US",
        gender: .female,
        quality: .high
    )
    
    static let maleUS = TTSVoice(
        name: "en-US-Neural2-C",
        displayName: "Male Voice (US, Neural)",
        languageCode: "en-US",
        gender: .male,
        quality: .high
    )
}

enum TTSVoiceGender: String, CaseIterable {
    case male = "MALE"
    case female = "FEMALE"
    case neutral = "NEUTRAL"
}

enum TTSVoiceQuality: String, CaseIterable {
    case standard = "STANDARD"
    case high = "WAVENET"
    case premium = "NEURAL2"
}

enum TTSAudioEncoding: String, CaseIterable {
    case linear16 = "LINEAR16"
    case mp3 = "MP3"
    case oggOpus = "OGG_OPUS"
}

/// TTS-specific errors
enum TTSError: LocalizedError {
    case textTooLong(maxLength: Int)
    case voiceNotAvailable(voiceName: String)
    case audioEncodingNotSupported(encoding: TTSAudioEncoding)
    case networkError(underlying: Error)
    case apiKeyMissing
    case quotaExceeded
    case invalidResponse
    case synthesisTimeout
    
    var errorDescription: String? {
        switch self {
        case .textTooLong(let maxLength):
            return "Text is too long. Maximum length is \(maxLength) characters."
        case .voiceNotAvailable(let voiceName):
            return "Voice '\(voiceName)' is not available."
        case .audioEncodingNotSupported(let encoding):
            return "Audio encoding '\(encoding.rawValue)' is not supported."
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .apiKeyMissing:
            return "API key is missing or invalid."
        case .quotaExceeded:
            return "TTS quota has been exceeded."
        case .invalidResponse:
            return "Invalid response from TTS service."
        case .synthesisTimeout:
            return "TTS synthesis timed out."
        }
    }
}

// MARK: - Platform-specific TTS Service Implementations

#if os(watchOS)
/// Watch-specific TTS service using backend API
class WatchTTSService: TTSServiceProtocol {
    
    var availableVoices: [TTSVoice] {
        return [.sulafat, .maleUS, .femaleUS]
    }
    
    var supportsSSML: Bool { return true }
    var maxTextLength: Int { return 5000 }
    
    func synthesizeText(
        _ text: String,
        settings: TTSVoiceSettings = TTSVoiceSettings.platformDefault,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        
        guard text.count <= maxTextLength else {
            completion(.failure(TTSError.textTooLong(maxLength: maxTextLength)))
            return
        }
        
        // Use backend TTS service via API call
        synthesizeViaBackend(text, settings: settings, completion: completion)
    }
    
    private func synthesizeViaBackend(
        _ text: String,
        settings: TTSVoiceSettings,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        
        // Use backend TTS endpoint
        guard let url = URL(string: "https://floe.cognetica.de/api/voice/synthesize") else {
            completion(.failure(TTSError.networkError(underlying: URLError(.badURL))))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("voice-assistant-api-key-2024", forHTTPHeaderField: "X-API-Key")
        
        let requestBody: [String: Any] = [
            "text": text,
            "voice": settings.voiceName,
            "languageCode": settings.languageCode,
            "speakingRate": settings.speakingRate,
            "pitch": settings.pitch,
            "volumeGainDb": settings.volumeGainDb,
            "audioEncoding": settings.audioEncoding.rawValue
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(TTSError.networkError(underlying: error)))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(TTSError.networkError(underlying: error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(TTSError.invalidResponse))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 429 {
                    completion(.failure(TTSError.quotaExceeded))
                } else {
                    completion(.failure(TTSError.invalidResponse))
                }
                return
            }
            
            guard let data = data else {
                completion(.failure(TTSError.invalidResponse))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let audioContent = json["audioBase64"] as? String,
                   let audioData = Data(base64Encoded: audioContent) {
                    completion(.success(audioData))
                } else {
                    completion(.failure(TTSError.invalidResponse))
                }
            } catch {
                completion(.failure(TTSError.networkError(underlying: error)))
            }
        }.resume()
    }
}

#else
/// iPhone-specific TTS service
class iPhoneTTSService: TTSServiceProtocol {
    
    var availableVoices: [TTSVoice] {
        return [.femaleUS, .sulafat, .maleUS]
    }
    
    var supportsSSML: Bool { return true }
    var maxTextLength: Int { return 5000 }
    
    func synthesizeText(
        _ text: String,
        settings: TTSVoiceSettings = TTSVoiceSettings.platformDefault,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        
        guard text.count <= maxTextLength else {
            completion(.failure(TTSError.textTooLong(maxLength: maxTextLength)))
            return
        }
        
        // Use backend TTS service via API call or GoogleTTSService
        // For now, we'll use a similar approach to the Watch
        synthesizeViaAPI(text, settings: settings, completion: completion)
    }
    
    private func synthesizeViaAPI(
        _ text: String,
        settings: TTSVoiceSettings,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        
        let url = URL(string: "https://texttospeech.googleapis.com/v1/text:synthesize")!
        
        // Get API key (same approach as Watch)
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            completion(.failure(TTSError.apiKeyMissing))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        
        let requestBody: [String: Any] = [
            "input": ["text": text],
            "voice": [
                "languageCode": settings.languageCode,
                "name": settings.voiceName,
                "ssmlGender": "NEUTRAL"
            ],
            "audioConfig": [
                "audioEncoding": settings.audioEncoding.rawValue,
                "speakingRate": settings.speakingRate,
                "pitch": settings.pitch,
                "volumeGainDb": settings.volumeGainDb
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(TTSError.networkError(underlying: error)))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(TTSError.networkError(underlying: error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(TTSError.invalidResponse))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 429 {
                    completion(.failure(TTSError.quotaExceeded))
                } else {
                    completion(.failure(TTSError.invalidResponse))
                }
                return
            }
            
            guard let data = data else {
                completion(.failure(TTSError.invalidResponse))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let audioContent = json["audioContent"] as? String,
                   let audioData = Data(base64Encoded: audioContent) {
                    completion(.success(audioData))
                } else {
                    completion(.failure(TTSError.invalidResponse))
                }
            } catch {
                completion(.failure(TTSError.networkError(underlying: error)))
            }
        }.resume()
    }
    
    private func getAPIKey() -> String? {
        // Try multiple sources for API key
        if let key = Bundle.main.infoDictionary?["GOOGLE_TTS_API_KEY"] as? String, !key.isEmpty {
            return key
        }
        
        if let key = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_TTS_API_KEY") as? String, !key.isEmpty {
            return key
        }
        
        return nil
    }
}
#endif

// MARK: - Mock TTS Service for Testing

/// Mock TTS service for testing and development
class MockTTSService: TTSServiceProtocol {
    
    var availableVoices: [TTSVoice] {
        return [.femaleUS, .maleUS, .sulafat]
    }
    
    var supportsSSML: Bool { return true }
    var maxTextLength: Int { return 5000 }
    
    var simulateFailure: Bool = false
    var synthesisDelay: TimeInterval = 0.5
    
    func synthesizeText(
        _ text: String,
        settings: TTSVoiceSettings = TTSVoiceSettings.platformDefault,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        
        guard text.count <= maxTextLength else {
            completion(.failure(TTSError.textTooLong(maxLength: maxTextLength)))
            return
        }
        
        if simulateFailure {
            DispatchQueue.global().asyncAfter(deadline: .now() + synthesisDelay) {
                completion(.failure(TTSError.networkError(underlying: URLError(.networkConnectionLost))))
            }
            return
        }
        
        // Generate mock audio data
        DispatchQueue.global().asyncAfter(deadline: .now() + synthesisDelay) {
            let mockAudioData = self.generateMockAudioData(for: text)
            completion(.success(mockAudioData))
        }
    }
    
    private func generateMockAudioData(for text: String) -> Data {
        // Generate mock MP3 data based on text length
        let baseSize = 1000
        let textMultiplier = text.count * 10
        let totalSize = baseSize + textMultiplier
        
        var audioData = Data([0xFF, 0xFB, 0x90, 0x00]) // MP3 header
        audioData.append(Data(repeating: 0x00, count: totalSize))
        
        return audioData
    }
}