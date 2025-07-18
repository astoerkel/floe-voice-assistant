import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Main voice interface
            EnhancedVoiceView()
                .tag(0)
            
            // Quick actions for common tasks
            NavigationView {
                QuickActionsView()
                    .navigationTitle("Actions")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tag(1)
            
            // Today's agenda (offline-capable)
            NavigationView {
                TodayView()
                    .navigationTitle("Today")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tag(2)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        .ignoresSafeArea(.container, edges: .bottom)
    }
}


#Preview {
    ContentView()
}
