import SwiftUI

/// Battery optimization settings and monitoring view
struct BatteryOptimizationView: View {
    @StateObject private var performanceOptimizer = MLPerformanceOptimizer()
    
    var body: some View {
        List {
            // Battery Impact Monitor
            Section {
                BatteryImpactView()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            
            // Power Mode Settings
            Section {
                PowerModeSettingsView(performanceOptimizer: performanceOptimizer)
            } header: {
                Text("Power Management")
            } footer: {
                Text("Automatically adjust performance based on battery level and charging state.")
            }
            
            // Battery Usage Breakdown
            Section {
                BatteryUsageBreakdownView()
            } header: {
                Text("Power Consumption")
            }
            
            // Energy Saving Tips
            Section {
                EnergySavingTipsView(performanceOptimizer: performanceOptimizer)
            } header: {
                Text("Energy Saving Tips")
            }
            
            // Advanced Battery Settings
            Section {
                AdvancedBatterySettingsView(performanceOptimizer: performanceOptimizer)
            } header: {
                Text("Advanced Settings")
            } footer: {
                Text("These settings affect how the app behaves under different power conditions.")
            }
        }
        .navigationTitle("Battery Optimization")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Supporting Views

struct PowerModeSettingsView: View {
    @ObservedObject var performanceOptimizer: MLPerformanceOptimizer
    @State private var autoPowerSaving = true
    @State private var powerSavingThreshold: Double = 20.0
    @State private var thermalThrottling = true
    
    var body: some View {
        VStack(spacing: 12) {
            Toggle("Auto Power Saving", isOn: $autoPowerSaving)
            
            if autoPowerSaving {
                VStack(spacing: 8) {
                    HStack {
                        Text("Power Saving Threshold")
                        Spacer()
                        Text("\(Int(powerSavingThreshold))%")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $powerSavingThreshold, in: 10...50, step: 5)
                }
                
                Text("Automatically switch to power saving mode when battery drops below this level.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Toggle("Thermal Throttling", isOn: $thermalThrottling)
            
            if thermalThrottling {
                Text("Automatically reduce performance when device gets hot to prevent battery drain.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Current power mode indicator
            HStack {
                Text("Current Mode")
                    .font(.subheadline)
                
                Spacer()
                
                Text(performanceOptimizer.currentMode.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
}

struct BatteryUsageBreakdownView: View {
    private let components = [
        ("Neural Engine", 0.35, Color.blue),
        ("CPU Processing", 0.25, Color.green),
        ("GPU Acceleration", 0.20, Color.purple),
        ("Memory Access", 0.15, Color.orange),
        ("Network & I/O", 0.05, Color.red)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(components, id: \.0) { component in
                BatteryUsageRow(
                    component: component.0,
                    usage: component.1,
                    color: component.2
                )
            }
            
            // Total estimated usage
            HStack {
                Text("Estimated Battery Impact")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("~8% per hour")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
}

struct BatteryUsageRow: View {
    let component: String
    let usage: Double
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

struct EnergySavingTipsView: View {
    @ObservedObject var performanceOptimizer: MLPerformanceOptimizer
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(energySavingTips, id: \.0) { tip in
                EnergySavingTipRow(
                    icon: tip.0,
                    title: tip.1,
                    description: tip.2,
                    isRelevant: tip.3
                )
            }
        }
    }
    
    private var energySavingTips: [(String, String, String, Bool)] {
        [
            (
                "bolt.circle",
                "Charge During Heavy Usage",
                "Use high-performance mode when plugged in for best results.",
                !performanceOptimizer.isCharging && performanceOptimizer.currentMode == .highPerformance
            ),
            (
                "thermometer",
                "Keep Device Cool",
                "Avoid using in direct sunlight or hot environments.",
                performanceOptimizer.thermalState.shouldThrottle
            ),
            (
                "speedometer",
                "Use Balanced Mode",
                "Switch to balanced mode for optimal battery life.",
                performanceOptimizer.currentMode == .highPerformance && performanceOptimizer.batteryLevel < 0.5
            ),
            (
                "cpu",
                "Enable Quantization",
                "Model quantization reduces power consumption significantly.",
                true
            ),
            (
                "moon",
                "Reduce Background Usage",
                "Close unused apps to free up system resources.",
                true
            )
        ]
    }
}

struct EnergySavingTipRow: View {
    let icon: String
    let title: String
    let description: String
    let isRelevant: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isRelevant ? .green : .secondary)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isRelevant ? .primary : .secondary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isRelevant {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
        .opacity(isRelevant ? 1.0 : 0.6)
    }
}

struct AdvancedBatterySettingsView: View {
    @ObservedObject var performanceOptimizer: MLPerformanceOptimizer
    @State private var backgroundProcessingEnabled = true
    @State private var lowPowerModeDetection = true
    @State private var adaptiveBrightness = true
    @State private var networkOptimization = true
    
    var body: some View {
        VStack(spacing: 12) {
            Toggle("Background Processing", isOn: $backgroundProcessingEnabled)
            
            if backgroundProcessingEnabled {
                Text("Allow processing when app is in background. Disable to save battery.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Toggle("Low Power Mode Detection", isOn: $lowPowerModeDetection)
            
            if lowPowerModeDetection {
                Text("Automatically adjust performance when iOS Low Power Mode is enabled.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Toggle("Adaptive Brightness", isOn: $adaptiveBrightness)
            
            if adaptiveBrightness {
                Text("Reduce screen brightness during processing to save power.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Toggle("Network Optimization", isOn: $networkOptimization)
            
            if networkOptimization {
                Text("Optimize network requests to reduce cellular radio usage.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Battery health information
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Battery Health")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Optimizations are working to preserve battery health")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "heart.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
}

#Preview {
    NavigationStack {
        BatteryOptimizationView()
    }
}