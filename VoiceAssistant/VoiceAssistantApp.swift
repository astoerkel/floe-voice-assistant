import SwiftUI

@main
struct VoiceAssistantApp: App {
    @StateObject private var apiClient = SimpleAPIClient.shared
    
    var body: some Scene {
        WindowGroup {
            SimpleContentView()
        }
    }
}