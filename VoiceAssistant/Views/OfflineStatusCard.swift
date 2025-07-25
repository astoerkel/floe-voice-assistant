//
//  OfflineStatusCard.swift
//  VoiceAssistant
//
//  Created by Claude on 24.07.25.
//

import SwiftUI

struct OfflineStatusCard: View {
    let mode: OfflineTransitionManager.ProcessingMode
    let connectionQuality: OfflineTransitionManager.ConnectionStatus.ConnectionQuality
    let availableCapabilities: [String]
    let queuedCommandsCount: Int
    let isDegraded: Bool
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Mode icon and title
                HStack(spacing: 8) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(mode.color))
                    
                    Text(mode.description)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Connection quality indicator
                if mode != .offline {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(connectionQualityColor)
                            .frame(width: 6, height: 6)
                        
                        Text(connectionQuality.description)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Expand/collapse button
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            // Status description
            Text(statusDescription)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(isExpanded ? nil : 1)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    // Capabilities and queue info
                    if mode == .offline || !availableCapabilities.isEmpty {
                        HStack {
                            if mode == .offline && !availableCapabilities.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Available offline:")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    Text(availableCapabilities.prefix(3).joined(separator: ", "))
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            if queuedCommandsCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 10))
                                    Text("\(queuedCommandsCount) queued")
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(backgroundGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    private var connectionQualityColor: Color {
        switch connectionQuality {
        case .unknown: return .gray
        case .poor: return .red
        case .fair: return .orange
        case .good: return .blue
        case .excellent: return .green
        }
    }
    
    private var backgroundGradient: LinearGradient {
        let baseColor: Color = {
            switch mode {
            case .online: return .green
            case .offline: return .orange
            case .hybrid: return .blue
            case .degraded: return .red
            }
        }()
        
        return LinearGradient(
            colors: [
                baseColor.opacity(0.2),
                baseColor.opacity(0.1),
                Color.black.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var borderColor: Color {
        switch mode {
        case .online: return .green.opacity(0.3)
        case .offline: return .orange.opacity(0.3)
        case .hybrid: return .blue.opacity(0.3)
        case .degraded: return .red.opacity(0.3)
        }
    }
    
    private var statusDescription: String {
        switch mode {
        case .online:
            return "All features available with full internet connectivity"
        case .offline:
            return "Working offline. Commands will sync when connection is restored."
        case .hybrid:
            return "Smart processing - using both online and offline capabilities"
        case .degraded:
            return isDegraded ? "Limited functionality due to connection issues" : "Running in reduced capability mode"
        }
    }
}

// MARK: - Connection Quality Extension
extension OfflineTransitionManager.ConnectionStatus.ConnectionQuality {
    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
}

#Preview {
    VStack {
        OfflineStatusCard(
            mode: .offline,
            connectionQuality: .unknown,
            availableCapabilities: ["Calendar Queries", "Reminders & Notes", "Time & Date"],
            queuedCommandsCount: 3,
            isDegraded: false
        )
        
        OfflineStatusCard(
            mode: .hybrid,
            connectionQuality: .fair,
            availableCapabilities: [],
            queuedCommandsCount: 0,
            isDegraded: false
        )
    }
    .padding()
    .background(Color.black)
}