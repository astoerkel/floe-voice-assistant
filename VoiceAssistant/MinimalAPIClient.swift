import Foundation

/// Minimal API client for Phase 2 - Real API Integration
class MinimalAPIClient {
    static let shared = MinimalAPIClient()
    
    private let baseURL = Constants.API.baseURL
    private let apiKey = Constants.API.apiKey
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.API.requestTimeout
        config.timeoutIntervalForResource = Constants.API.requestTimeout
        self.session = URLSession(configuration: config)
    }
    
    /// Process audio file by uploading to backend API
    func processAudio(url: URL) async throws -> String {
        guard let audioData = try? Data(contentsOf: url) else {
            throw APIError.fileReadError
        }
        
        // Use the process-audio endpoint
        guard let apiURL = URL(string: "\(baseURL)/api/voice/process-audio") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        var body = Data()
        
        // Add sessionId field
        let sessionId = Constants.getCurrentSessionId()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"sessionId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(sessionId)\r\n".data(using: .utf8)!)
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Debug logging
        print("📤 Sending audio to API:")
        print("   URL: \(apiURL)")
        print("   Audio size: \(audioData.count) bytes")
        print("   Session ID: \(sessionId)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            print("📥 API Response:")
            print("   Status: \(httpResponse.statusCode)")
            print("   Headers: \(httpResponse.allHeaderFields)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Body preview: \(responseString.prefix(200))...")
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }
            
            // Parse the response
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(APIResponse.self, from: data)
            
            // Extract the text response
            if let text = apiResponse.response?.text {
                return text
            } else if let transcribedText = apiResponse.transcribedText {
                // Fallback to transcribed text if no response
                return "Transcribed: \(transcribedText)"
            } else {
                throw APIError.noResponseText
            }
            
        } catch {
            print("❌ API Error: \(error)")
            throw error
        }
    }
    
    /// Process text directly (for testing)
    func processText(_ text: String) async throws -> String {
        guard let apiURL = URL(string: "\(baseURL)/api/voice/process-text") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let requestBody: [String: Any] = [
            "text": text,
            "sessionId": Constants.getCurrentSessionId(),
            "context": [
                "platform": "iOS",
                "deviceModel": "iPhone"
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("📤 Sending text to API: \(text)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("📥 API Response: \(httpResponse.statusCode)")
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if let text = apiResponse.response?.text {
            return text
        } else {
            throw APIError.noResponseText
        }
    }
}

// MARK: - Error Types

enum APIError: LocalizedError {
    case fileReadError
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case noResponseText
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .fileReadError:
            return "Failed to read audio file"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "Server error: HTTP \(code)"
        case .noResponseText:
            return "No response text from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

// MARK: - Response Models

struct APIResponse: Codable {
    let transcribedText: String?
    let response: ResponseText?
    let confidence: Double?
    let sessionId: String?
    let audioResponse: AudioResponse?
    let processingTime: Int?
    let agentUsed: String?
    
    struct ResponseText: Codable {
        let text: String
        let suggestions: [String]?
        let action: String?
    }
    
    struct AudioResponse: Codable {
        let audioBase64: String
        let duration: Double?
    }
}

// MARK: - Data Extension for Multipart

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}