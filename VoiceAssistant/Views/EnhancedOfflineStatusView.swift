//
//  EnhancedOfflineStatusView.swift
//  VoiceAssistant
//
//  Enhanced offline status display showing cache status and background sync
//

import SwiftUI

struct EnhancedOfflineStatusView: View {
    @ObservedObject var enhancementManager: OfflineEnhancementManager
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main status header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: cacheStatusIcon)
                        .foregroundColor(cacheStatusColor)
                        .font(.caption)
                    
                    Text(enhancementManager.enhancedCacheStatus.displayText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    if enhancementManager.totalCachedItems > 0 {
                        Text("\(enhancementManager.totalCachedItems) items")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // Cache metrics
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Smart Caching")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text(enhancementManager.smartCachingEnabled ? "Enabled" : "Disabled")
                                .font(.caption2)
                                .foregroundColor(enhancementManager.smartCachingEnabled ? .green : .orange)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Background Sync")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text(enhancementManager.backgroundSyncEnabled ? "Enabled" : "Disabled")
                                .font(.caption2)
                                .foregroundColor(enhancementManager.backgroundSyncEnabled ? .green : .orange)
                        }
                    }
                    
                    // Last update time
                    if let lastUpdate = enhancementManager.lastCacheUpdate {
                        HStack {
                            Text("Last Updated:")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Spacer()
                            
                            Text(formatRelativeTime(lastUpdate))
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button("Refresh Cache") {
                            enhancementManager.refreshCacheData()
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .disabled(enhancementManager.enhancedCacheStatus == .updating)
                        
                        Spacer()
                        
                        if case .error = enhancementManager.enhancedCacheStatus {
                            Button("Retry") {
                                enhancementManager.initializeCache()
                            }
                            .font(.caption2)
                            .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                )
        )
        .padding(.horizontal, 4)
    }
    
    // MARK: - Computed Properties
    
    private var cacheStatusIcon: String {
        switch enhancementManager.enhancedCacheStatus {
        case .initializing:
            return "arrow.clockwise"
        case .ready:
            return "checkmark.circle.fill"
        case .updating:
            return "arrow.clockwise"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var cacheStatusColor: Color {
        switch enhancementManager.enhancedCacheStatus {
        case .initializing, .updating:
            return .blue
        case .ready:
            return .green
        case .error:
            return .orange
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

#Preview {
    EnhancedOfflineStatusView(
        enhancementManager: OfflineEnhancementManager()
    )
    .background(Color.black)
    .padding()
}