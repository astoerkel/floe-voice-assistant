import SwiftUI

@main
struct VoiceAssistantApp: App {
    @StateObject private var apiClient = SimpleAPIClient.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isLoading = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoading {
                    LoadingView()
                        .transition(.opacity)
                } else {
                    SimpleContentView()
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(themeManager.currentTheme)
            .onAppear {
                // Simulate loading time for app initialization
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isLoading = false
                    }
                }
            }
            .onOpenURL { url in
                handleIncomingURL(url)
            }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        guard let scheme = url.scheme else { return }
        
        // Handle OAuth callbacks
        if scheme == "voiceassistant" && url.host == "oauth" {
            // Parse OAuth callback parameters
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems
            let hasSuccess = queryItems?.contains { $0.name == "success" } ?? false
            let hasError = queryItems?.contains { $0.name == "error" } ?? false
            
            if hasSuccess {
                // Sync tokens from SimpleAPIClient to APIClient
                APIClient.shared.syncTokensFromSimpleAPIClient()
                
                // Notify OAuthManager that OAuth completed successfully
                NotificationCenter.default.post(name: .oauthStatusChanged, object: nil)
            } else if hasError {
                // Handle OAuth error
                if let error = queryItems?.first(where: { $0.name == "error" })?.value {
                    print("OAuth error: \(error)")
                }
            }
        }
    }
}