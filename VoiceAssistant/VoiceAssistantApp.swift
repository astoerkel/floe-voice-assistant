import SwiftUI

@main
struct VoiceAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // For development: bypass all authentication and show minimal view
            ContentView()
            #else
            // Production app would go here
            ContentView()
            #endif
        }
    }
}