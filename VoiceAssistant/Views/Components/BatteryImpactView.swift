import SwiftUI
import Combine

/// Battery impact visualization view for Core ML performance monitoring
struct BatteryImpactView: View {
    @StateObject private var performanceOptimizer = MLPerformanceOptimizer()
    @State private var isExpanded = false
    @State private var showingDetails = false
    
    private let updateInterval: TimeInterval = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            if isExpanded {
                // Detailed battery impact content
                VStack(spacing: 16) {
                    // Current battery status
                    batteryStatusSection
                    
                    // Power consumption breakdown
                    powerConsumptionSection
                    
                    // Usage recommendations
                    recommendationsSection
                }
                .padding()
                .background(Color(.systemGroupedBackground))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "battery.100")
                    .foregroundColor(batteryIconColor)
                
                Text("Battery Impact")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // Quick status
            HStack(spacing: 4) {
                Text(batteryStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if performanceOptimizer.isCharging {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
    }
    
    private var batteryStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Status")
                .font(.headline)
            
            HStack(spacing: 16) {
                // Battery level visualization
                BatteryLevelIndicator(
                    level: performanceOptimizer.batteryLevel,
                    isCharging: performanceOptimizer.isCharging
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Level:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(performanceOptimizer.batteryLevel * 100))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Status:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(performanceOptimizer.isCharging ? "Charging" : "Discharging")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(performanceOptimizer.isCharging ? .green : .primary)
                    }
                    
                    if !performanceOptimizer.isCharging {
                        HStack {
                            Text("Est. Drain:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(estimatedDrainText)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(drainRateColor)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    private var powerConsumptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Power Consumption")
                .font(.headline)
            
            VStack(spacing: 8) {
                PowerConsumptionRow(
                    component: "Neural Engine",
                    usage: neuralEngineUsage,
                    color: .blue
                )
                
                PowerConsumptionRow(
                    component: "CPU Processing",
                    usage: cpuUsage,
                    color: .green
                )
                
                PowerConsumptionRow(
                    component: "GPU Acceleration",
                    usage: gpuUsage,
                    color: .purple
                )
                
                PowerConsumptionRow(
                    component: "Memory Access",
                    usage: memoryUsage,
                    color: .orange
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Power Optimization")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(batteryRecommendations, id: \.self) { recommendation in
                    BatteryRecommendationCard(text: recommendation)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct BatteryLevelIndicator: View {
    let level: Float
    let isCharging: Bool
    
    var body: some View {
        ZStack {
            // Battery outline
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.primary, lineWidth: 2)
                .frame(width: 60, height: 32)
            
            // Battery terminal
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.primary)
                .frame(width: 4, height: 12)
                .offset(x: 32)
            
            // Battery fill
            RoundedRectangle(cornerRadius: 2)
                .fill(batteryFillColor(for: level))
                .frame(width: CGFloat(level) * 54, height: 26)
                .offset(x: -3 + CGFloat(level) * 27)
            
            // Charging indicator
            if isCharging {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.white)
                    .font(.caption)
                    .shadow(color: .black.opacity(0.3), radius: 1)
            }
        }
    }
    
    private func batteryFillColor(for level: Float) -> Color {
        if level > 0.5 { return .green }
        if level > 0.2 { return .yellow }
        return .red
    }
}

struct PowerConsumptionRow: View {
    let component: String
    let usage: Double // 0.0 to 1.0
    let color: Color
    
    var body: some View {
        HStack {
            Text(component)
                .font(.subheadline)
                .frame(width: 120, alignment: .leading)
            
            // Usage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * usage, height: 6)
                        .animation(.easeInOut(duration: 0.5), value: usage)
                }
            }
            .frame(height: 6)
            
            Text("\(Int(usage * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

struct BatteryRecommendationCard: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "battery.100")
                .foregroundColor(.green)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(6)
    }
}

// MARK: - Computed Properties

extension BatteryImpactView {
    private var batteryIconColor: Color {
        if performanceOptimizer.batteryLevel > 0.5 { return .green }
        if performanceOptimizer.batteryLevel > 0.2 { return .orange }
        return .red
    }
    
    private var batteryStatusText: String {
        "\(Int(performanceOptimizer.batteryLevel * 100))%"
    }
    
    private var estimatedDrainText: String {
        let drainRate = estimatedDrainRate
        return String(format: "%.1f%%/hr", drainRate * 100)
    }
    
    private var drainRateColor: Color {
        let drainRate = estimatedDrainRate
        if drainRate > 0.15 { return .red }
        if drainRate > 0.08 { return .orange }
        return .green
    }
    
    private var estimatedDrainRate: Double {
        // Base drain rate calculation
        var drainRate = 0.05 // 5% per hour baseline
        
        // Increase based on performance mode
        switch performanceOptimizer.currentMode {
        case .highPerformance:
            drainRate *= 2.0
        case .balanced:
            drainRate *= 1.3
        case .powerSaving:
            drainRate *= 0.7
        case .adaptive:
            drainRate *= 1.0
        }
        
        // Increase based on thermal state
        if performanceOptimizer.thermalState.shouldThrottle {
            drainRate *= 1.4
        }
        
        return drainRate
    }
    
    // Simulated component usage (in real implementation, these would be actual measurements)
    private var neuralEngineUsage: Double {
        switch performanceOptimizer.currentMode {
        case .highPerformance: return 0.8
        case .balanced: return 0.5
        case .powerSaving: return 0.1
        case .adaptive: return 0.6
        }
    }
    
    private var cpuUsage: Double {
        switch performanceOptimizer.currentMode {
        case .highPerformance: return 0.6
        case .balanced: return 0.7
        case .powerSaving: return 0.9
        case .adaptive: return 0.7
        }
    }
    
    private var gpuUsage: Double {
        switch performanceOptimizer.currentMode {
        case .highPerformance: return 0.7
        case .balanced: return 0.3
        case .powerSaving: return 0.0
        case .adaptive: return 0.4
        }
    }
    
    private var memoryUsage: Double {
        return 0.4 // Relatively constant
    }
    
    private var batteryRecommendations: [String] {
        var recommendations: [String] = []
        
        if performanceOptimizer.batteryLevel < 0.2 && !performanceOptimizer.isCharging {
            recommendations.append("Enable Power Saving mode for extended battery life")
        }
        
        if performanceOptimizer.thermalState.shouldThrottle {
            recommendations.append("Device is hot - reduce processing load to save battery")
        }
        
        if performanceOptimizer.currentMode == .highPerformance && !performanceOptimizer.isCharging {
            recommendations.append("Consider Balanced mode when not charging")
        }
        
        if neuralEngineUsage > 0.7 && performanceOptimizer.batteryLevel < 0.5 {
            recommendations.append("High Neural Engine usage detected - consider quantization")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Battery usage is optimized for current settings")
        }
        
        return recommendations
    }
}

#Preview {
    BatteryImpactView()
        .padding()
        .background(Color(.systemGroupedBackground))
}