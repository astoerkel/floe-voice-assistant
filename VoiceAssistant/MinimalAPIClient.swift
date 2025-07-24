import Foundation

class MinimalAPIClient {
    static let shared = MinimalAPIClient()
    private let baseURL = "https://floe.cognetica.de"
    
    func processAudio(url: URL) async throws -> String {
        // For now, just return mock data
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return "This is a mock response from the minimal API client"
    }
}