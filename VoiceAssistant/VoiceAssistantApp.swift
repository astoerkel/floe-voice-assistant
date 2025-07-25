import SwiftUI

@main
struct VoiceAssistantApp: App {
    @StateObject private var oauthService = OAuthService.shared
    
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // For development: bypass all authentication and show minimal view
            ContentView()
                .onOpenURL { url in
                    // Handle OAuth callbacks
                    print("📱 App received URL: \(url)")
                    handleOAuthCallback(url)
                }
            #else
            // Production app would go here
            ContentView()
                .onOpenURL { url in
                    // Handle OAuth callbacks
                    print("📱 App received URL: \(url)")
                    handleOAuthCallback(url)
                }
            #endif
        }
    }
    
    private func handleOAuthCallback(_ url: URL) {
        // Handle OAuth callback URLs
        if url.scheme == "voiceassistant" && url.host == "oauth" {
            // Extract query parameters
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []
            
            // Convert to dictionary
            var params: [String: String] = [:]
            for item in queryItems {
                params[item.name] = item.value
            }
            
            print("📱 OAuth callback received with params: \(params)")
            
            // Handle the success callback from backend
            if let success = params["success"] {
                Task {
                    await oauthService.handleSuccessCallback(success: success, params: params)
                }
            } else if let error = params["error"] {
                print("❌ OAuth error received: \(error)")
                Task {
                    await oauthService.handleErrorCallback(error: error)
                }
            }
        }
    }
}