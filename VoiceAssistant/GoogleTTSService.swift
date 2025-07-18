//
//  GoogleTTSService.swift
//  VoiceAssistant
//
//  Created by Claude on 17.07.25.
//

import Foundation
import AVFoundation

class GoogleTTSService {
    static let shared = GoogleTTSService()
    
    private let apiKey: String = {
        // For development, you can hardcode the key here
        // For production, consider using a secure configuration method
        if let key = Bundle.main.infoDictionary?["GOOGLE_TTS_API_KEY"] as? String {
            print("🔑 GoogleTTS: API key loaded from Info.plist (length: \(key.count))")
            return key
        }
        print("❌ GoogleTTS: API key not found in Info.plist")
        return "YOUR_ACTUAL_GOOGLE_API_KEY_HERE" // Replace with your Google Cloud API key
    }()
    private let baseURL = "https://texttospeech.googleapis.com/v1/text:synthesize"
    
    private init() {}
    
    func synthesizeText(_ text: String, completion: @escaping (Result<Data, Error>) -> Void) {
        // Always use the actual Google TTS API for real audio
        print("🔊 GoogleTTS: Using actual Google TTS API")
        synthesizeWithGoogleAPI(text, completion: completion)
    }
    
    private func generateMockAudioResponse(for text: String, completion: @escaping (Result<Data, Error>) -> Void) {
        // Create a simple mock response that represents the text
        let mockResponse = """
        {
            "audioContent": "\(createMockAudioBase64(for: text))"
        }
        """
        
        if let data = mockResponse.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let audioContent = json?["audioContent"] as? String,
                   let audioData = Data(base64Encoded: audioContent) {
                    completion(.success(audioData))
                } else {
                    completion(.failure(GoogleTTSError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        } else {
            completion(.failure(GoogleTTSError.invalidResponse))
        }
    }
    
    private func createMockAudioBase64(for text: String) -> String {
        // Create a simple mock audio file (MP3 format)
        // This is a minimal MP3 header + some audio data
        let mp3Header: [UInt8] = [
            0xFF, 0xFB, 0x90, 0x00, // MP3 header
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ]
        
        // Add some mock audio data based on text length
        let audioData = mp3Header + Array(repeating: UInt8(0x00), count: min(text.count * 10, 1000))
        
        return Data(audioData).base64EncodedString()
    }
    
    private func synthesizeWithGoogleAPI(_ text: String, completion: @escaping (Result<Data, Error>) -> Void) {
        guard !apiKey.isEmpty && !apiKey.contains("YOUR_ACTUAL_GOOGLE_API_KEY_HERE") else {
            print("❌ GoogleTTS: API key not configured")
            completion(.failure(GoogleTTSError.apiKeyMissing))
            return
        }
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(GoogleTTSError.invalidURL))
            return
        }
        
        print("🔊 GoogleTTS: Making API request to Google TTS")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        
        let requestBody: [String: Any] = [
            "input": ["text": text],
            "voice": [
                "languageCode": "en-GB",
                "name": "en-GB-Chirp3-HD-Sulafat",
                "ssmlGender": "NEUTRAL"
            ],
            "audioConfig": [
                "audioEncoding": "MP3",
                "speakingRate": 1.0,
                "pitch": 0.0,
                "volumeGainDb": 0.0
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ GoogleTTS: Network error: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ GoogleTTS: Invalid response type")
                completion(.failure(GoogleTTSError.invalidResponse))
                return
            }
            
            print("🔊 GoogleTTS: HTTP Status: \(httpResponse.statusCode)")
            
            guard let data = data else {
                print("❌ GoogleTTS: No data received")
                completion(.failure(GoogleTTSError.noData))
                return
            }
            
            print("🔊 GoogleTTS: Received \(data.count) bytes")
            
            // Log the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔊 GoogleTTS: Raw response: \(responseString)")
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let audioContent = json["audioContent"] as? String,
                   let audioData = Data(base64Encoded: audioContent) {
                    print("✅ GoogleTTS: Successfully decoded audio (\(audioData.count) bytes)")
                    completion(.success(audioData))
                } else {
                    print("❌ GoogleTTS: Failed to parse JSON or extract audio content")
                    completion(.failure(GoogleTTSError.invalidResponse))
                }
            } catch {
                print("❌ GoogleTTS: JSON parsing error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
}

enum GoogleTTSError: LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    case apiKeyMissing
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Google TTS URL"
        case .noData:
            return "No data received from Google TTS"
        case .invalidResponse:
            return "Invalid response from Google TTS"
        case .apiKeyMissing:
            return "Google TTS API key missing"
        }
    }
}
