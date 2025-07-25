import SwiftUI

struct TodayView: View {
    @ObservedObject private var phoneConnector = PhoneConnector.shared
    @StateObject private var offlineManager = OfflineManager()
    @State private var currentTime = Date()
    @State private var refreshTimer: Timer?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header with current time
                headerView
                
                // Connection status
                connectionStatusView
                
                // Today's agenda
                if phoneConnector.isConnected {
                    onlineAgendaView
                } else {
                    offlineAgendaView
                }
                
                // Queued commands indicator
                if offlineManager.queuedCommands.count > 0 {
                    queuedCommandsView
                }
            }
            .padding()
        }
        .onAppear {
            startTimeUpdates()
        }
        .onDisappear {
            stopTimeUpdates()
        }
        .refreshable {
            await refreshData()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 4) {
            Text("Today")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(currentTime.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(currentTime.formatted(.dateTime.hour().minute()))
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    private var connectionStatusView: some View {
        HStack {
            Circle()
                .fill(phoneConnector.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            
            Text(phoneConnector.isConnected ? "Connected to iPhone" : "Offline Mode")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var onlineAgendaView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Agenda")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            // Mock agenda items - in real implementation, this would come from phone
            AgendaItem(
                title: "Team Meeting",
                time: "9:00 AM",
                type: .meeting,
                isNext: true
            )
            
            AgendaItem(
                title: "Review PRs",
                time: "11:00 AM",
                type: .task,
                isNext: false
            )
            
            AgendaItem(
                title: "Lunch with Sarah",
                time: "12:30 PM",
                type: .personal,
                isNext: false
            )
            
            AgendaItem(
                title: "Client Call",
                time: "3:00 PM",
                type: .meeting,
                isNext: false
            )
        }
    }
    
    private var offlineAgendaView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cached Agenda")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if let cachedData = offlineManager.cachedData {
                ForEach(cachedData.todayEvents, id: \.self) { event in
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(event)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                
                // Last sync time
                Text("Last sync: \(cachedData.lastSyncTime.formatted(.dateTime.hour().minute()))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } else {
                Text("No cached data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
    
    private var queuedCommandsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Queued Commands")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Text("\(offlineManager.queuedCommands.count) commands waiting")
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if phoneConnector.isConnected {
                    Button("Sync Now") {
                        Task {
                            await offlineManager.syncQueuedCommands()
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(6)
        }
    }
    
    private func startTimeUpdates() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopTimeUpdates() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func refreshData() async {
        // In a real implementation, this would fetch fresh data from the phone
        // For now, we'll just update the current time
        currentTime = Date()
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
}

struct AgendaItem: View {
    let title: String
    let time: String
    let type: AgendaItemType
    let isNext: Bool
    
    enum AgendaItemType {
        case meeting
        case task
        case personal
        
        var icon: String {
            switch self {
            case .meeting: return "person.2.fill"
            case .task: return "checkmark.circle"
            case .personal: return "person.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .meeting: return .blue
            case .task: return .orange
            case .personal: return .green
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: type.icon)
                .font(.caption)
                .foregroundColor(type.color)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(isNext ? .medium : .regular)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isNext {
                Text("Next")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(type.color)
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isNext ? type.color.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isNext ? type.color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    TodayView()
}